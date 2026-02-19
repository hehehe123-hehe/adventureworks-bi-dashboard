/* ===============================================================================
MASTER CLEANING SCRIPT: HUMAN RESOURCES SCHEMA
Project: AdventureWorks 2025
Description: Comprehensive data cleaning for all HR tables.
===============================================================================
*/
use AdventureWorks2025;
go

--1. TABLE: HumanResources.Department
select 
	departmentID,
	trim(Name) as DeptName,
	trim(groupName) as Division,
	ModifiedDate
from HumanResources.Department

-- 2. TABLE: HumanResources.Employee
select 
	BusinessEntityID,
	NationalIDNumber,
	JobTitle,
	cast(BirthDate as date) as BirthDate,
	cast(HireDate as date) as HireDate,
	-- calculation of age ad tenure years
	DATEDIFF(year, BirthDate, GETDATE()) as Age,
	DATEDIFF(year,HireDate, GETDATE()) as TenureYears,
	-- state of standarization
	case MaritalStatus
		when 'M' then 'Married' 
		when 'S' then 'Single'
		else 'N/A' 
	end as MaritalStatus,
	case Gender
		when 'M' then 'Male'
		when 'F' then 'Female'
		else 'N/A'
	end as Gender,
	-- Flagging for HR
	case when SalariedFlag = 1 then 'Monthly Salary'
		else 'Hourly Wage'
	end as PaymetType,
	case when CurrentFlag = 1 then 'Active'
		else 'Inactive'
	end as EmploymetStatus
from HumanResources.Employee;
	
-- 3. TABLE: HumanResources.EmployeeDepartmentHistory
select
	BusinessEntityID,
	DepartmentID,
	ShiftID,
	cast(StartDate as date) as StartDate,
	-- if endDate is null
	isnull(cast(EndDate as date),'9999-12-31') as EndDateClean,
	case
		when EndDate is null then 'Active Assignment'
		else 'Previous Assignment'
	end as AssignmentStatus,
	DATEDIFF(month, StartDate, ISNULL(EndDate, getdate())) as MonthsInRole
from HumanResources.EmployeeDepartmentHistory;

-- 4. TABLE: HumanResources.EmployeePayHistory
select 
	BusinessEntityID,
	cast(RateChangeDate as date) as RateChangeDate,
	round(Rate, 2) as HourlyRate,
	-- estimated annual salary
	round(Rate * 40 * 52, 2) as EstimatedAnnualSalary, -- 40 hours, 52 weeks
	case PayFrequency
		when 1 then 'Monthly'
		when 2 then 'Bi-Weekly'
	end as PayFrequencyDesc

from HumanResources.EmployeePayHistory;

-- 5. TABLE: HumanResources.JobCandidate
select 
	JobCandidateID, BusinessEntityID,
	case 
		when Resume is not null then 'Resume Uploaded'
		else 'No Resume'
	end as ApplicationStatus,
	ModifiedDate
from HumanResources.JobCandidate;

-- 6. TABLE: HumanResources.Shift
select 
	ShiftID, Name as ShiftName,
	-- Time only
	cast(StartTime as time(0)) as StartTime,
	cast(EndTime as time(0)) as EndTime,
	--work duration
	case
		when EndTime < StartTime
		then DATEDIFF(hour, StartTime, EndTime) + 24
		else DATEDIFF(hour, StartTime, EndTime)
	end as ShiftHours
from HumanResources.Shift;

