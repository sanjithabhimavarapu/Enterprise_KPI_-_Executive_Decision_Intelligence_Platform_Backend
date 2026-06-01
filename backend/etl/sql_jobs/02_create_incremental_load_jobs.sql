-- ============================================================
-- SQL SERVER AGENT JOBS: INCREMENTAL DATA LOADS
-- ============================================================
-- Purpose: Individual jobs for incremental loads from each source
-- Schedules: Staggered timings before master orchestration
-- ============================================================

USE msdb;
GO

-- ============================================================
-- JOB 1: INCREMENTAL ERP ORDERS LOAD
-- ============================================================
-- Schedule: Daily at 12:30 AM (before orchestration at 2:00 AM)

DECLARE @ReturnCode INT = 0;
DECLARE @JobName NVARCHAR(128) = 'ETL_Incremental_ERP_Orders_Load';
DECLARE @JobID UNIQUEIDENTIFIER;

-- Drop if exists
IF EXISTS (SELECT * FROM dbo.sysjobs WHERE name = @JobName)
    EXEC sp_delete_job @job_name = @JobName, @delete_unused_schedule = 1;
GO

DECLARE @ReturnCode INT = 0;
DECLARE @JobName NVARCHAR(128) = 'ETL_Incremental_ERP_Orders_Load';
DECLARE @JobID UNIQUEIDENTIFIER;

EXEC @ReturnCode = sp_add_job 
    @job_name = @JobName,
    @enabled = 1,
    @start_step_name = 'Load_ERP_Orders',
    @description = 'Incremental load of ERP orders data with change tracking',
    @category_name = N'[Uncategorized (Local)]',
    @owner_login_name = N'sa',
    @job_id = @JobID OUTPUT;

IF @ReturnCode = 0
BEGIN
    EXEC @ReturnCode = sp_add_jobstep
        @job_id = @JobID,
        @step_name = N'Load_ERP_Orders',
        @step_id = 1,
        @cmdexec_success_code = 0,
        @on_success_action = 1,
        @on_fail_action = 2,
        @retry_attempts = 3,
        @retry_interval = 5,
        @subsystem = N'TSQL',
        @database_name = N'Enterprise_KPI_DW',
        @command = N'
            DECLARE @LastLoadTime DATETIME2;
            DECLARE @CurrentLoadTime DATETIME2 = GETDATE();
            DECLARE @RecordsInserted INT = 0;
            DECLARE @RecordsUpdated INT = 0;
            
            BEGIN TRY
                -- Get last successful load time
                SELECT @LastLoadTime = MAX(last_load_time) 
                FROM etl_incremental_checkpoints 
                WHERE source_system = ''ERP'' AND table_name = ''Orders'';
                
                IF @LastLoadTime IS NULL
                    SET @LastLoadTime = DATEADD(DAY, -1, @CurrentLoadTime);
                
                -- Load ERP Orders (simulated - replace with actual ERP connector)
                INSERT INTO stg_raw_erp_orders 
                    (order_id, customer_id, order_date, amount, status, load_date, source_modified_date)
                SELECT 
                    order_id, customer_id, order_date, amount, status, 
                    @CurrentLoadTime, modified_date
                FROM erp_source.dbo.orders
                WHERE modified_date > @LastLoadTime;
                
                SET @RecordsInserted = @@ROWCOUNT;
                
                -- Update checkpoint
                UPDATE etl_incremental_checkpoints
                SET last_load_time = @CurrentLoadTime,
                    record_count = @RecordsInserted,
                    last_status = ''SUCCESS''
                WHERE source_system = ''ERP'' AND table_name = ''Orders'';
                
                INSERT INTO etl_logs (process_name, process_step, record_count, status, log_date)
                VALUES (''ETL_Incremental_ERP_Orders_Load'', ''Load_ERP_Orders'', @RecordsInserted, 
                        ''SUCCESS'', @CurrentLoadTime);
            END TRY
            BEGIN CATCH
                INSERT INTO etl_logs (process_name, status, log_date, details)
                VALUES (''ETL_Incremental_ERP_Orders_Load'', ''FAILED'', GETDATE(), ERROR_MESSAGE());
                RAISERROR(ERROR_MESSAGE(), 16, 1);
            END CATCH;
        ';
        
    EXEC sp_add_schedule
        @schedule_name = N'Daily_0130AM_ERP_Orders',
        @freq_type = 4,
        @freq_interval = 1,
        @active_start_time = 013000;
        
    EXEC sp_attach_schedule
        @job_id = @JobID,
        @schedule_name = N'Daily_0130AM_ERP_Orders';
        
    EXEC sp_add_jobserver @job_id = @JobID, @server_name = @@SERVERNAME;
    
    PRINT 'Job created: ' + @JobName;
END;
GO

-- ============================================================
-- JOB 2: INCREMENTAL SALESFORCE CUSTOMERS LOAD
-- ============================================================
-- Schedule: Daily at 1:00 AM

DECLARE @ReturnCode INT = 0;
DECLARE @JobName NVARCHAR(128) = 'ETL_Incremental_Salesforce_Customers_Load';
DECLARE @JobID UNIQUEIDENTIFIER;

IF EXISTS (SELECT * FROM dbo.sysjobs WHERE name = @JobName)
    EXEC sp_delete_job @job_name = @JobName, @delete_unused_schedule = 1;
GO

DECLARE @ReturnCode INT = 0;
DECLARE @JobName NVARCHAR(128) = 'ETL_Incremental_Salesforce_Customers_Load';
DECLARE @JobID UNIQUEIDENTIFIER;

EXEC @ReturnCode = sp_add_job 
    @job_name = @JobName,
    @enabled = 1,
    @start_step_name = 'Load_Salesforce_Customers',
    @description = 'Incremental load of Salesforce customer data',
    @category_name = N'[Uncategorized (Local)]',
    @owner_login_name = N'sa',
    @job_id = @JobID OUTPUT;

IF @ReturnCode = 0
BEGIN
    EXEC @ReturnCode = sp_add_jobstep
        @job_id = @JobID,
        @step_name = N'Load_Salesforce_Customers',
        @step_id = 1,
        @cmdexec_success_code = 0,
        @on_success_action = 1,
        @on_fail_action = 2,
        @retry_attempts = 3,
        @retry_interval = 5,
        @subsystem = N'TSQL',
        @database_name = N'Enterprise_KPI_DW',
        @command = N'
            DECLARE @LastLoadTime DATETIME2;
            DECLARE @CurrentLoadTime DATETIME2 = GETDATE();
            DECLARE @RecordsProcessed INT = 0;
            
            BEGIN TRY
                -- Get last successful load time
                SELECT @LastLoadTime = MAX(last_load_time) 
                FROM etl_incremental_checkpoints 
                WHERE source_system = ''SALESFORCE'' AND table_name = ''Customers'';
                
                IF @LastLoadTime IS NULL
                    SET @LastLoadTime = DATEADD(DAY, -1, @CurrentLoadTime);
                
                -- Load Salesforce Customers (use Salesforce connector or API)
                INSERT INTO stg_raw_salesforce_customers 
                    (account_id, account_name, industry, revenue, status, load_date, source_modified_date)
                SELECT 
                    account_id, name, industry, annual_revenue, status,
                    @CurrentLoadTime, last_modified_date
                FROM salesforce_source.dbo.accounts
                WHERE last_modified_date > @LastLoadTime;
                
                SET @RecordsProcessed = @@ROWCOUNT;
                
                -- Update checkpoint
                UPDATE etl_incremental_checkpoints
                SET last_load_time = @CurrentLoadTime,
                    record_count = @RecordsProcessed,
                    last_status = ''SUCCESS''
                WHERE source_system = ''SALESFORCE'' AND table_name = ''Customers'';
                
                INSERT INTO etl_logs (process_name, record_count, status, log_date)
                VALUES (''ETL_Incremental_Salesforce_Customers_Load'', @RecordsProcessed, 
                        ''SUCCESS'', @CurrentLoadTime);
            END TRY
            BEGIN CATCH
                INSERT INTO etl_logs (process_name, status, log_date, details)
                VALUES (''ETL_Incremental_Salesforce_Customers_Load'', ''FAILED'', GETDATE(), 
                        ERROR_MESSAGE());
                RAISERROR(ERROR_MESSAGE(), 16, 1);
            END CATCH;
        ';
        
    EXEC sp_add_schedule
        @schedule_name = N'Daily_0100AM_Salesforce_Customers',
        @freq_type = 4,
        @freq_interval = 1,
        @active_start_time = 010000;
        
    EXEC sp_attach_schedule
        @job_id = @JobID,
        @schedule_name = N'Daily_0100AM_Salesforce_Customers';
        
    EXEC sp_add_jobserver @job_id = @JobID, @server_name = @@SERVERNAME;
    
    PRINT 'Job created: ' + @JobName;
END;
GO

-- ============================================================
-- JOB 3: INCREMENTAL INVENTORY LOAD
-- ============================================================
-- Schedule: Daily at 12:45 AM

DECLARE @ReturnCode INT = 0;
DECLARE @JobName NVARCHAR(128) = 'ETL_Incremental_Inventory_Load';
DECLARE @JobID UNIQUEIDENTIFIER;

IF EXISTS (SELECT * FROM dbo.sysjobs WHERE name = @JobName)
    EXEC sp_delete_job @job_name = @JobName, @delete_unused_schedule = 1;
GO

DECLARE @ReturnCode INT = 0;
DECLARE @JobName NVARCHAR(128) = 'ETL_Incremental_Inventory_Load';
DECLARE @JobID UNIQUEIDENTIFIER;

EXEC @ReturnCode = sp_add_job 
    @job_name = @JobName,
    @enabled = 1,
    @start_step_name = 'Load_Inventory',
    @description = 'Incremental load of inventory data',
    @category_name = N'[Uncategorized (Local)]',
    @owner_login_name = N'sa',
    @job_id = @JobID OUTPUT;

IF @ReturnCode = 0
BEGIN
    EXEC @ReturnCode = sp_add_jobstep
        @job_id = @JobID,
        @step_name = N'Load_Inventory',
        @step_id = 1,
        @cmdexec_success_code = 0,
        @on_success_action = 1,
        @on_fail_action = 2,
        @retry_attempts = 3,
        @retry_interval = 5,
        @subsystem = N'TSQL',
        @database_name = N'Enterprise_KPI_DW',
        @command = N'
            DECLARE @LastLoadTime DATETIME2;
            DECLARE @CurrentLoadTime DATETIME2 = GETDATE();
            DECLARE @RecordsProcessed INT = 0;
            
            BEGIN TRY
                SELECT @LastLoadTime = MAX(last_load_time) 
                FROM etl_incremental_checkpoints 
                WHERE source_system = ''INVENTORY'' AND table_name = ''Stock'';
                
                IF @LastLoadTime IS NULL
                    SET @LastLoadTime = DATEADD(DAY, -1, @CurrentLoadTime);
                
                -- Load Inventory Data
                INSERT INTO stg_raw_inventory
                    (product_id, warehouse_id, quantity_on_hand, last_count_date, load_date)
                SELECT 
                    product_id, warehouse_id, qty_on_hand, last_physical_count, @CurrentLoadTime
                FROM inventory_source.dbo.stock_levels
                WHERE last_physical_count > @LastLoadTime;
                
                SET @RecordsProcessed = @@ROWCOUNT;
                
                UPDATE etl_incremental_checkpoints
                SET last_load_time = @CurrentLoadTime,
                    record_count = @RecordsProcessed,
                    last_status = ''SUCCESS''
                WHERE source_system = ''INVENTORY'' AND table_name = ''Stock'';
                
                INSERT INTO etl_logs (process_name, record_count, status, log_date)
                VALUES (''ETL_Incremental_Inventory_Load'', @RecordsProcessed, ''SUCCESS'', @CurrentLoadTime);
            END TRY
            BEGIN CATCH
                INSERT INTO etl_logs (process_name, status, log_date, details)
                VALUES (''ETL_Incremental_Inventory_Load'', ''FAILED'', GETDATE(), ERROR_MESSAGE());
                RAISERROR(ERROR_MESSAGE(), 16, 1);
            END CATCH;
        ';
        
    EXEC sp_add_schedule
        @schedule_name = N'Daily_0045AM_Inventory',
        @freq_type = 4,
        @freq_interval = 1,
        @active_start_time = 004500;
        
    EXEC sp_attach_schedule
        @job_id = @JobID,
        @schedule_name = N'Daily_0045AM_Inventory';
        
    EXEC sp_add_jobserver @job_id = @JobID, @server_name = @@SERVERNAME;
    
    PRINT 'Job created: ' + @JobName;
END;
GO

PRINT 'All incremental load jobs created successfully!';
