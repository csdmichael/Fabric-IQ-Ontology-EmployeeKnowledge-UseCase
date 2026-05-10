// Power Query M Script - Load Employee Data into OneLake
// Paste this into Power BI Desktop → Get Data → Web (blank query)

section EmployeeKnowledgeOneLake;

// Configuration
let
    WorkspaceId = "38362838-0531-4215-89af-a8a79221b545",
    LakehouseId = "d11b209f-c774-481e-adcb-79920a94fd20",
    
    // Source data paths (relative to GitHub or OneDrive)
    DataSource = "https://raw.githubusercontent.com/yourgithub/Fabric-IQ-Ontology-EmployeeKnowledge-UseCase/main/data/",
    
    // Load Employees
    EmployeesSource = Json.Document(Web.Contents(DataSource & "employees.json")),
    EmployeesTable = Table.FromList(EmployeesSource, Splitter.SplitByNothing(), null, null, ExtraValues.Error),
    EmployeesExpanded = Table.ExpandRecordColumn(EmployeesTable, "Column1", 
        {"employeeId", "displayName", "email", "department", "role", "location", "skills", "hireDate"}, 
        {"employeeId", "displayName", "email", "department", "role", "location", "skills", "hireDate"}),
    EmployeesNormalized = Table.TransformColumnTypes(EmployeesExpanded, {
        {"employeeId", type text},
        {"displayName", type text},
        {"email", type text},
        {"department", type text},
        {"role", type text},
        {"location", type text},
        {"skills", type text},
        {"hireDate", type date}
    }),
    
    // Load Contributions
    ContributionsSource = Json.Document(Web.Contents(DataSource & "contributions.json")),
    ContributionsTable = Table.FromList(ContributionsSource, Splitter.SplitByNothing(), null, null, ExtraValues.Error),
    ContributionsExpanded = Table.ExpandRecordColumn(ContributionsTable, "Column1",
        {"employeeId", "department", "location", "projectIds", "projectCount", "activeProjectCount", "completedProjectCount", "assetCount", "presentationCount", "documentCount", "reportCount", "emailActivityCount", "mentoringSessionCount", "codeCommitCount", "contributionScore", "tier"},
        {"employeeId", "department", "location", "projectIds", "projectCount", "activeProjectCount", "completedProjectCount", "assetCount", "presentationCount", "documentCount", "reportCount", "emailActivityCount", "mentoringSessionCount", "codeCommitCount", "contributionScore", "tier"}),
    ContributionsNormalized = Table.TransformColumnTypes(ContributionsExpanded, {
        {"employeeId", type text},
        {"projectCount", type number},
        {"activeProjectCount", type number},
        {"assetCount", type number},
        {"codeCommitCount", type number},
        {"contributionScore", type number},
        {"tier", type text}
    }),
    ContributionsRemoved = Table.RemoveColumns(ContributionsNormalized, {"projectIds"}),
    
    // Load Digital Assets
    AssetsSource = Json.Document(Web.Contents(DataSource & "digital_assets.json")),
    AssetsTable = Table.FromList(AssetsSource, Splitter.SplitByNothing(), null, null, ExtraValues.Error),
    AssetsExpanded = Table.ExpandRecordColumn(AssetsTable, "Column1",
        {"assetId", "employeeId", "assetType", "format", "title", "sourceSystem", "lastModified"},
        {"assetId", "employeeId", "assetType", "format", "title", "sourceSystem", "lastModified"}),
    AssetsNormalized = Table.TransformColumnTypes(AssetsExpanded, {
        {"assetId", type text},
        {"employeeId", type text},
        {"assetType", type text},
        {"title", type text},
        {"lastModified", type date}
    }),
    
    // Load Projects
    ProjectsSource = Json.Document(Web.Contents(DataSource & "projects.json")),
    ProjectsTable = Table.FromList(ProjectsSource, Splitter.SplitByNothing(), null, null, ExtraValues.Error),
    ProjectsExpanded = Table.ExpandRecordColumn(ProjectsTable, "Column1",
        {"projectId", "name", "description", "department", "status", "lead"},
        {"projectId", "projectName", "description", "department", "status", "lead"}),
    ProjectsNormalized = Table.TransformColumnTypes(ProjectsExpanded, {
        {"projectId", type text},
        {"projectName", type text},
        {"status", type text},
        {"lead", type text}
    })

in
    [
        Employees = EmployeesNormalized,
        Contributions = ContributionsNormalized,
        DigitalAssets = AssetsNormalized,
        Projects = ProjectsNormalized
    ]
