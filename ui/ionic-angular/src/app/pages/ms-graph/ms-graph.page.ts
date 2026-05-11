import { Component } from '@angular/core';

type GraphUser = {
  graphUserId: string;
  employeeId: string;
  displayName: string;
  mail: string;
  jobTitle: string;
  department: string;
  officeLocation: string;
  presenceStatus: string;
  lastActiveDateTime: string;
  driveItemCount: number;
  sharedWithMe: number;
  teamsMessageCount: number;
  calendarEventsThisWeek: number;
  skills: string[];
};

type GraphFile = {
  graphItemId: string;
  employeeId: string;
  name: string;
  mimeType: string;
  size: number;
  webUrl: string;
  createdDateTime: string;
  lastModifiedDateTime: string;
  source: string;
  aiSearchIndexed: boolean;
};

type GraphEmail = {
  graphMessageId: string;
  employeeId: string;
  subject: string;
  receivedDateTime: string;
  from: string;
  toRecipients: string[];
  hasAttachments: boolean;
  importance: string;
  isRead: boolean;
  bodyPreview: string;
};

type GraphData = {
  syncedAt: string;
  sources: string[];
  summary: {
    totalUsers: number;
    totalFiles: number;
    totalEmails: number;
    totalTeamsMessages: number;
    totalCalendarEvents: number;
  };
  users: GraphUser[];
  recentFiles: GraphFile[];
  recentEmails: GraphEmail[];
};

const PRESENCE_COLORS: Record<string, string> = {
  Available: 'success',
  Busy: 'danger',
  Away: 'warning',
  'Do Not Disturb': 'danger',
  Offline: 'medium',
};

@Component({
  selector: 'app-ms-graph',
  templateUrl: './ms-graph.page.html',
  styleUrls: ['./ms-graph.page.scss']
})
export class MsGraphPage {
  description = 'Microsoft Graph ingests M365 data — SharePoint files, OneDrive documents, Outlook emails, Teams activity, and calendar events — into Microsoft Fabric OneLake via Graph Connectors and Fabric Dataflow Gen2.';

  graphData?: GraphData;
  selectedUser?: GraphUser;
  activeTab: 'users' | 'files' | 'emails' = 'users';
  loadError = '';

  get presenceColors() {
    return PRESENCE_COLORS;
  }

  presenceColor(status: string): string {
    return PRESENCE_COLORS[status] ?? 'medium';
  }

  formatBytes(bytes: number): string {
    if (bytes < 1024) return `${bytes} B`;
    if (bytes < 1024 * 1024) return `${(bytes / 1024).toFixed(1)} KB`;
    return `${(bytes / (1024 * 1024)).toFixed(1)} MB`;
  }

  fileIcon(mimeType: string): string {
    if (mimeType.includes('pdf')) return '📄';
    if (mimeType.includes('presentation')) return '📊';
    if (mimeType.includes('spreadsheet') || mimeType.includes('excel')) return '📗';
    if (mimeType.includes('word') || mimeType.includes('document')) return '📝';
    return '📎';
  }

  selectUser(user: GraphUser): void {
    this.selectedUser = this.selectedUser?.graphUserId === user.graphUserId ? undefined : user;
  }

  setTab(tab: 'users' | 'files' | 'emails'): void {
    this.activeTab = tab;
  }

  constructor() {
    this.initialize().catch((err: unknown) => {
      this.loadError = `Unable to load Microsoft Graph data: ${err instanceof Error ? err.message : String(err)}`;
    });
  }

  async initialize(): Promise<void> {
    this.graphData = await this.readJson<GraphData>('/api/graph-data');
  }

  private async readJson<T>(url: string): Promise<T> {
    const response = await fetch(url);
    if (!response.ok) throw new Error(`${response.status} ${response.statusText}`);
    return response.json() as Promise<T>;
  }
}
