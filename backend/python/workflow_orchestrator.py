"""
Advanced Workflow Orchestration Engine
========================================
Enterprise-grade orchestration with dependency management, error handling,
retry strategies, monitoring, and recovery logic.
"""

import logging
import sys
from datetime import datetime, timedelta
from typing import Optional, Dict, List, Callable, Tuple
from enum import Enum
from dataclasses import dataclass, field, asdict
from pathlib import Path
import json
import traceback
from abc import ABC, abstractmethod

from database import init_db, DatabaseConfig, close_db

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    handlers=[
        logging.StreamHandler(sys.stdout),
        logging.FileHandler(f'logs/orchestration_{datetime.now().strftime("%Y%m%d_%H%M%S")}.log')
    ]
)

logger = logging.getLogger(__name__)


# ============================================================
# ENUMS & DATA CLASSES
# ============================================================

class TaskStatus(Enum):
    """Task execution status."""
    PENDING = "PENDING"
    RUNNING = "RUNNING"
    SUCCESS = "SUCCESS"
    FAILED = "FAILED"
    SKIPPED = "SKIPPED"
    RETRYING = "RETRYING"
    ROLLED_BACK = "ROLLED_BACK"


class AlertSeverity(Enum):
    """Alert severity levels."""
    INFO = "INFO"
    WARNING = "WARNING"
    ERROR = "ERROR"
    CRITICAL = "CRITICAL"


class RetryStrategy(Enum):
    """Retry strategy types."""
    EXPONENTIAL_BACKOFF = "EXPONENTIAL_BACKOFF"
    LINEAR_BACKOFF = "LINEAR_BACKOFF"
    IMMEDIATE = "IMMEDIATE"
    CIRCUIT_BREAKER = "CIRCUIT_BREAKER"


@dataclass
class RetryPolicy:
    """Retry policy configuration."""
    strategy: RetryStrategy = RetryStrategy.EXPONENTIAL_BACKOFF
    max_attempts: int = 3
    initial_delay_seconds: int = 5
    max_delay_seconds: int = 300
    backoff_multiplier: float = 2.0
    jitter: bool = True


@dataclass
class TaskDependency:
    """Task dependency definition."""
    task_id: str
    required: bool = True  # If False, task continues even if dependency fails


@dataclass
class TaskContext:
    """Execution context for a task."""
    task_id: str
    task_name: str
    status: TaskStatus = TaskStatus.PENDING
    start_time: Optional[datetime] = None
    end_time: Optional[datetime] = None
    duration_seconds: float = 0.0
    attempt: int = 0
    max_attempts: int = 3
    error: Optional[str] = None
    error_type: Optional[str] = None
    metadata: Dict = field(default_factory=dict)
    
    def to_dict(self) -> Dict:
        """Convert to dictionary."""
        return {
            'task_id': self.task_id,
            'task_name': self.task_name,
            'status': self.status.value,
            'start_time': self.start_time.isoformat() if self.start_time else None,
            'end_time': self.end_time.isoformat() if self.end_time else None,
            'duration_seconds': self.duration_seconds,
            'attempt': self.attempt,
            'max_attempts': self.max_attempts,
            'error': self.error,
            'error_type': self.error_type,
            'metadata': self.metadata
        }


@dataclass
class Alert:
    """Alert for workflow events."""
    severity: AlertSeverity
    message: str
    task_id: Optional[str] = None
    timestamp: datetime = field(default_factory=datetime.now)
    metadata: Dict = field(default_factory=dict)


# ============================================================
# RETRY STRATEGY IMPLEMENTATIONS
# ============================================================

class RetryHandler:
    """Handles retry logic with various strategies."""
    
    def __init__(self, policy: RetryPolicy):
        self.policy = policy
        self.failure_count = 0
        self.circuit_open = False
        self.circuit_open_time = None
        
    def get_delay(self, attempt: int) -> float:
        """Calculate delay for given attempt number."""
        if self.policy.strategy == RetryStrategy.IMMEDIATE:
            return 0
        
        elif self.policy.strategy == RetryStrategy.LINEAR_BACKOFF:
            delay = self.policy.initial_delay_seconds * attempt
            
        elif self.policy.strategy == RetryStrategy.EXPONENTIAL_BACKOFF:
            delay = self.policy.initial_delay_seconds * (
                self.policy.backoff_multiplier ** (attempt - 1)
            )
        else:
            delay = self.policy.initial_delay_seconds
        
        # Cap the delay
        delay = min(delay, self.policy.max_delay_seconds)
        
        # Add jitter if enabled
        if self.policy.jitter:
            import random
            delay *= (0.5 + random.random())
        
        return delay
    
    def should_retry(self, attempt: int) -> bool:
        """Check if retry should occur."""
        if self.policy.strategy == RetryStrategy.CIRCUIT_BREAKER:
            if self.circuit_open:
                # Check if circuit can be reset (30 seconds timeout)
                elapsed = (datetime.now() - self.circuit_open_time).total_seconds()
                if elapsed > 30:
                    self.circuit_open = False
                    self.failure_count = 0
                    logger.info("Circuit breaker reset after timeout")
                    return True
                return False
            
            # Open circuit if too many failures
            if self.failure_count >= 3:
                self.circuit_open = True
                self.circuit_open_time = datetime.now()
                logger.warning("Circuit breaker opened due to repeated failures")
                return False
        
        return attempt < self.policy.max_attempts
    
    def record_failure(self):
        """Record a failure."""
        self.failure_count += 1
    
    def reset(self):
        """Reset retry handler."""
        self.failure_count = 0
        self.circuit_open = False


# ============================================================
# WORKFLOW TASK
# ============================================================

class WorkflowTask:
    """Base workflow task."""
    
    def __init__(
        self,
        task_id: str,
        task_name: str,
        execute_func: Callable,
        retry_policy: Optional[RetryPolicy] = None,
        timeout_seconds: Optional[int] = None,
        dependencies: Optional[List[TaskDependency]] = None,
        rollback_func: Optional[Callable] = None,
        on_failure: Optional[Callable] = None,
    ):
        self.task_id = task_id
        self.task_name = task_name
        self.execute_func = execute_func
        self.retry_policy = retry_policy or RetryPolicy()
        self.timeout_seconds = timeout_seconds
        self.dependencies = dependencies or []
        self.rollback_func = rollback_func
        self.on_failure = on_failure
        self.context = TaskContext(task_id, task_name, max_attempts=self.retry_policy.max_attempts)
        self.retry_handler = RetryHandler(self.retry_policy)
        
    async def execute(self) -> bool:
        """Execute task with retry logic."""
        self.context.status = TaskStatus.RUNNING
        self.context.start_time = datetime.now()
        
        while True:
            self.context.attempt += 1
            
            try:
                logger.info(f"Executing task {self.task_name} (Attempt {self.context.attempt}/{self.context.max_attempts})")
                
                # Execute the task
                result = self.execute_func(self.context)
                
                self.context.status = TaskStatus.SUCCESS
                self.context.end_time = datetime.now()
                self.context.duration_seconds = (
                    self.context.end_time - self.context.start_time
                ).total_seconds()
                
                logger.info(f"✓ Task {self.task_name} completed successfully ({self.context.duration_seconds:.2f}s)")
                return True
                
            except Exception as e:
                self.context.error = str(e)
                self.context.error_type = type(e).__name__
                
                logger.error(f"✗ Task {self.task_name} failed: {e}")
                logger.debug(traceback.format_exc())
                
                # Check if retry should occur
                if self.retry_handler.should_retry(self.context.attempt):
                    delay = self.retry_handler.get_delay(self.context.attempt)
                    self.context.status = TaskStatus.RETRYING
                    self.retry_handler.record_failure()
                    
                    logger.warning(
                        f"Retrying task {self.task_name} in {delay:.1f}s "
                        f"(Attempt {self.context.attempt + 1}/{self.context.max_attempts})"
                    )
                    
                    import time
                    time.sleep(delay)
                else:
                    # Max retries exceeded
                    self.context.status = TaskStatus.FAILED
                    self.context.end_time = datetime.now()
                    self.context.duration_seconds = (
                        self.context.end_time - self.context.start_time
                    ).total_seconds()
                    
                    logger.error(f"✗ Task {self.task_name} failed after {self.context.attempt} attempts")
                    
                    # Execute failure handler
                    if self.on_failure:
                        try:
                            self.on_failure(self.context)
                        except Exception as handler_error:
                            logger.error(f"Error in failure handler: {handler_error}")
                    
                    return False
    
    async def rollback(self) -> bool:
        """Rollback task if rollback function defined."""
        if not self.rollback_func:
            return True
        
        try:
            logger.info(f"Rolling back task {self.task_name}")
            self.rollback_func(self.context)
            self.context.status = TaskStatus.ROLLED_BACK
            logger.info(f"✓ Task {self.task_name} rolled back successfully")
            return True
        except Exception as e:
            logger.error(f"✗ Rollback failed for task {self.task_name}: {e}")
            return False
    
    def has_dependencies(self) -> bool:
        """Check if task has dependencies."""
        return len(self.dependencies) > 0


# ============================================================
# WORKFLOW ORCHESTRATOR
# ============================================================

class WorkflowOrchestrator:
    """Advanced workflow orchestration engine."""
    
    def __init__(self, workflow_id: str, workflow_name: str):
        self.workflow_id = workflow_id
        self.workflow_name = workflow_name
        self.tasks: Dict[str, WorkflowTask] = {}
        self.execution_order: List[str] = []
        self.task_results: Dict[str, TaskContext] = {}
        self.alerts: List[Alert] = []
        self.start_time: Optional[datetime] = None
        self.end_time: Optional[datetime] = None
        self.status = TaskStatus.PENDING
        
    def add_task(self, task: WorkflowTask) -> None:
        """Add task to workflow."""
        self.tasks[task.task_id] = task
        logger.info(f"Added task {task.task_name} ({task.task_id})")
    
    def add_alert(self, alert: Alert) -> None:
        """Add alert to workflow."""
        self.alerts.append(alert)
        logger.log(
            logging.WARNING if alert.severity.value == "WARNING" else 
            logging.ERROR if alert.severity.value == "ERROR" else
            logging.INFO,
            f"[{alert.severity.value}] {alert.message}"
        )
    
    def _validate_dependencies(self) -> bool:
        """Validate all task dependencies exist."""
        for task_id, task in self.tasks.items():
            for dep in task.dependencies:
                if dep.task_id not in self.tasks:
                    logger.error(f"Task {task_id} has undefined dependency: {dep.task_id}")
                    return False
        return True
    
    def _topological_sort(self) -> List[str]:
        """Sort tasks topologically based on dependencies."""
        from collections import defaultdict, deque
        
        # Build adjacency list and in-degree count
        graph = defaultdict(list)
        in_degree = defaultdict(int)
        
        for task_id in self.tasks:
            if task_id not in in_degree:
                in_degree[task_id] = 0
        
        for task_id, task in self.tasks.items():
            for dep in task.dependencies:
                graph[dep.task_id].append(task_id)
                in_degree[task_id] += 1
        
        # Kahn's algorithm
        queue = deque([task_id for task_id in self.tasks if in_degree[task_id] == 0])
        sorted_tasks = []
        
        while queue:
            current = queue.popleft()
            sorted_tasks.append(current)
            
            for neighbor in graph[current]:
                in_degree[neighbor] -= 1
                if in_degree[neighbor] == 0:
                    queue.append(neighbor)
        
        # Check for cycles
        if len(sorted_tasks) != len(self.tasks):
            logger.error("Circular dependency detected in workflow!")
            return []
        
        return sorted_tasks
    
    def _check_dependencies(self, task_id: str) -> Tuple[bool, List[str]]:
        """Check if all dependencies are satisfied."""
        task = self.tasks[task_id]
        failed_deps = []
        
        for dep in task.dependencies:
            dep_result = self.task_results.get(dep.task_id)
            
            if dep_result is None:
                # Dependency not executed
                if dep.required:
                    failed_deps.append(dep.task_id)
            elif dep_result.status == TaskStatus.FAILED:
                # Dependency failed
                if dep.required:
                    failed_deps.append(dep.task_id)
        
        return len(failed_deps) == 0, failed_deps
    
    async def execute(self, continue_on_error: bool = False) -> bool:
        """Execute workflow."""
        self.start_time = datetime.now()
        self.status = TaskStatus.RUNNING
        
        logger.info("=" * 70)
        logger.info(f"WORKFLOW EXECUTION: {self.workflow_name}")
        logger.info(f"Workflow ID: {self.workflow_id}")
        logger.info(f"Start Time: {self.start_time}")
        logger.info("=" * 70)
        
        # Validate dependencies
        if not self._validate_dependencies():
            self.status = TaskStatus.FAILED
            self.add_alert(Alert(
                AlertSeverity.CRITICAL,
                "Workflow validation failed: Invalid task dependencies"
            ))
            return False
        
        # Get execution order
        self.execution_order = self._topological_sort()
        if not self.execution_order:
            self.status = TaskStatus.FAILED
            self.add_alert(Alert(
                AlertSeverity.CRITICAL,
                "Workflow validation failed: Could not determine execution order (circular dependency?)"
            ))
            return False
        
        logger.info(f"Execution order: {' → '.join(self.execution_order)}")
        
        # Execute tasks
        failed_tasks = []
        
        for task_id in self.execution_order:
            task = self.tasks[task_id]
            
            # Check dependencies
            deps_ok, failed_deps = self._check_dependencies(task_id)
            
            if not deps_ok:
                logger.warning(f"Task {task.task_name} skipped: Failed dependencies {failed_deps}")
                task.context.status = TaskStatus.SKIPPED
                self.task_results[task_id] = task.context
                
                self.add_alert(Alert(
                    AlertSeverity.WARNING,
                    f"Task {task.task_name} skipped due to failed dependencies",
                    task_id=task_id,
                    metadata={'failed_deps': failed_deps}
                ))
                
                if not continue_on_error:
                    break
                continue
            
            # Execute task
            success = await task.execute()
            self.task_results[task_id] = task.context
            
            if not success:
                failed_tasks.append(task_id)
                logger.error(f"Task {task.task_name} failed")
                
                self.add_alert(Alert(
                    AlertSeverity.ERROR,
                    f"Task {task.task_name} failed: {task.context.error}",
                    task_id=task_id,
                    metadata={
                        'error_type': task.context.error_type,
                        'attempts': task.context.attempt
                    }
                ))
                
                if not continue_on_error:
                    break
        
        # Determine final status
        self.end_time = datetime.now()
        
        if len(failed_tasks) == 0:
            self.status = TaskStatus.SUCCESS
            logger.info("✓ Workflow completed successfully")
        else:
            self.status = TaskStatus.FAILED
            logger.error(f"✗ Workflow failed with {len(failed_tasks)} failed task(s)")
        
        self._print_summary()
        
        return self.status == TaskStatus.SUCCESS
    
    async def rollback(self) -> bool:
        """Rollback workflow (execute in reverse order)."""
        logger.info("=" * 70)
        logger.info("WORKFLOW ROLLBACK")
        logger.info("=" * 70)
        
        # Rollback in reverse order
        for task_id in reversed(self.execution_order):
            task = self.tasks[task_id]
            
            # Only rollback successfully executed tasks
            if self.task_results.get(task_id, TaskContext(task_id, task.task_name)).status == TaskStatus.SUCCESS:
                success = await task.rollback()
                if not success:
                    logger.error(f"Rollback failed for task {task.task_name}")
                    return False
        
        logger.info("✓ Workflow rolled back successfully")
        return True
    
    def _print_summary(self) -> None:
        """Print workflow execution summary."""
        logger.info("=" * 70)
        logger.info("WORKFLOW EXECUTION SUMMARY")
        logger.info("=" * 70)
        logger.info(f"Workflow: {self.workflow_name} ({self.workflow_id})")
        logger.info(f"Status: {self.status.value}")
        logger.info(f"Duration: {(self.end_time - self.start_time).total_seconds():.2f}s")
        logger.info("")
        
        # Task results
        logger.info("TASK RESULTS:")
        for task_id in self.execution_order:
            result = self.task_results.get(task_id)
            task = self.tasks[task_id]
            
            if result:
                status_symbol = "✓" if result.status == TaskStatus.SUCCESS else "✗" if result.status == TaskStatus.FAILED else "⊘"
                logger.info(
                    f"  {status_symbol} {task.task_name}: {result.status.value} "
                    f"({result.duration_seconds:.2f}s, Attempt {result.attempt}/{result.max_attempts})"
                )
                if result.error:
                    logger.info(f"     Error: {result.error}")
        
        # Alerts
        if self.alerts:
            logger.info("")
            logger.info("ALERTS:")
            for alert in self.alerts:
                logger.info(f"  [{alert.severity.value}] {alert.message}")
        
        logger.info("=" * 70)
    
    def get_execution_report(self) -> Dict:
        """Get execution report as dictionary."""
        return {
            'workflow_id': self.workflow_id,
            'workflow_name': self.workflow_name,
            'status': self.status.value,
            'start_time': self.start_time.isoformat() if self.start_time else None,
            'end_time': self.end_time.isoformat() if self.end_time else None,
            'duration_seconds': (self.end_time - self.start_time).total_seconds() if self.end_time else None,
            'execution_order': self.execution_order,
            'task_results': {
                task_id: result.to_dict()
                for task_id, result in self.task_results.items()
            },
            'alerts': [
                {
                    'severity': alert.severity.value,
                    'message': alert.message,
                    'task_id': alert.task_id,
                    'timestamp': alert.timestamp.isoformat(),
                    'metadata': alert.metadata
                }
                for alert in self.alerts
            ]
        }
    
    def save_report(self, filename: Optional[str] = None) -> str:
        """Save execution report to JSON file."""
        if not filename:
            filename = f"orchestration_report_{self.workflow_id}_{datetime.now().strftime('%Y%m%d_%H%M%S')}.json"
        
        filepath = Path('logs') / filename
        filepath.parent.mkdir(parents=True, exist_ok=True)
        
        with open(filepath, 'w') as f:
            json.dump(self.get_execution_report(), f, indent=2)
        
        logger.info(f"Execution report saved to {filepath}")
        return str(filepath)


# ============================================================
# HEALTH CHECK & MONITORING
# ============================================================

class WorkflowHealthMonitor:
    """Monitor workflow health and generate alerts."""
    
    def __init__(self, db_config: Optional[DatabaseConfig] = None):
        self.db_config = db_config or DatabaseConfig()
        self.alerts: List[Alert] = []
    
    def check_workflow_health(self, orchestrator: WorkflowOrchestrator) -> Dict:
        """Check workflow health metrics."""
        metrics = {
            'total_tasks': len(orchestrator.tasks),
            'successful_tasks': sum(
                1 for r in orchestrator.task_results.values()
                if r.status == TaskStatus.SUCCESS
            ),
            'failed_tasks': sum(
                1 for r in orchestrator.task_results.values()
                if r.status == TaskStatus.FAILED
            ),
            'skipped_tasks': sum(
                1 for r in orchestrator.task_results.values()
                if r.status == TaskStatus.SKIPPED
            ),
            'success_rate': 0.0,
            'total_duration': 0.0,
            'alerts_count': len(orchestrator.alerts),
            'critical_alerts': sum(1 for a in orchestrator.alerts if a.severity == AlertSeverity.CRITICAL)
        }
        
        if metrics['total_tasks'] > 0:
            metrics['success_rate'] = (
                metrics['successful_tasks'] / metrics['total_tasks']
            ) * 100
        
        if orchestrator.end_time and orchestrator.start_time:
            metrics['total_duration'] = (
                orchestrator.end_time - orchestrator.start_time
            ).total_seconds()
        
        return metrics
    
    def generate_health_report(self, orchestrator: WorkflowOrchestrator) -> str:
        """Generate health report."""
        metrics = self.check_workflow_health(orchestrator)
        
        report = f"""
WORKFLOW HEALTH REPORT
======================
Workflow: {orchestrator.workflow_name}
Status: {orchestrator.status.value}

METRICS:
- Total Tasks: {metrics['total_tasks']}
- Successful: {metrics['successful_tasks']}
- Failed: {metrics['failed_tasks']}
- Skipped: {metrics['skipped_tasks']}
- Success Rate: {metrics['success_rate']:.1f}%
- Duration: {metrics['total_duration']:.2f}s

ALERTS: {metrics['alerts_count']} (Critical: {metrics['critical_alerts']})
"""
        
        if orchestrator.alerts:
            report += "\nALERT DETAILS:\n"
            for alert in orchestrator.alerts:
                report += f"- [{alert.severity.value}] {alert.message}\n"
        
        return report


# ============================================================
# EXAMPLE USAGE
# ============================================================

if __name__ == "__main__":
    import asyncio
    
    # Define sample tasks
    async def sample_task_1(context: TaskContext):
        logger.info("Executing sample task 1")
        # Simulate work
        import time
        time.sleep(1)
        logger.info("Sample task 1 complete")
    
    async def sample_task_2(context: TaskContext):
        logger.info("Executing sample task 2")
        # Simulate work
        import time
        time.sleep(1)
        logger.info("Sample task 2 complete")
    
    async def sample_task_3(context: TaskContext):
        logger.info("Executing sample task 3")
        # Simulate work
        import time
        time.sleep(1)
        logger.info("Sample task 3 complete")
    
    async def main():
        # Create orchestrator
        orchestrator = WorkflowOrchestrator(
            "WORKFLOW_001",
            "Sample ETL Workflow"
        )
        
        # Add tasks
        task1 = WorkflowTask(
            "TASK_001",
            "Load Data",
            sample_task_1,
            retry_policy=RetryPolicy(max_attempts=3)
        )
        
        task2 = WorkflowTask(
            "TASK_002",
            "Validate Data",
            sample_task_2,
            retry_policy=RetryPolicy(max_attempts=2),
            dependencies=[TaskDependency("TASK_001", required=True)]
        )
        
        task3 = WorkflowTask(
            "TASK_003",
            "Reconcile Data",
            sample_task_3,
            retry_policy=RetryPolicy(max_attempts=2),
            dependencies=[
                TaskDependency("TASK_001", required=True),
                TaskDependency("TASK_002", required=True)
            ]
        )
        
        orchestrator.add_task(task1)
        orchestrator.add_task(task2)
        orchestrator.add_task(task3)
        
        # Execute workflow
        success = await orchestrator.execute(continue_on_error=False)
        
        # Generate health report
        monitor = WorkflowHealthMonitor()
        health_report = monitor.generate_health_report(orchestrator)
        print(health_report)
        
        # Save report
        orchestrator.save_report()
        
        return success
    
    # Run async main
    if sys.version_info >= (3, 7):
        exit_code = asyncio.run(main())
        sys.exit(0 if exit_code else 1)
    else:
        loop = asyncio.get_event_loop()
        exit_code = loop.run_until_complete(main())
        sys.exit(0 if exit_code else 1)
