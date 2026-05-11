import { Component } from '@angular/core';

export type NavSection = {
  title: string;
  icon: string;
  pages: { title: string; url: string; icon: string }[];
};

@Component({
  selector: 'app-root',
  templateUrl: 'app.component.html',
  styleUrls: ['app.component.scss']
})
export class AppComponent {
  readonly navSections: NavSection[] = [
    {
      title: 'Source Data',
      icon: '🗂️',
      pages: [
        { title: 'Employees',     url: '/employees',   icon: '👥' },
        { title: 'Org Structure', url: '/org-chart',   icon: '🏢' },
        { title: 'Projects',      url: '/projects',    icon: '🗂️' },
        { title: 'Digital Assets',url: '/data-sources',icon: '📂' }
      ]
    },
    {
      title: 'Reports & Dashboards',
      icon: '📊',
      pages: [
        { title: 'Leaderboard',        url: '/leaderboard',      icon: '🏆' },
        { title: 'Power BI Reports',   url: '/powerbi-reports',  icon: '📊' },
        { title: 'Ingestion Pipeline', url: '/ingestion-flow',   icon: '🔄' }
      ]
    },
    {
      title: 'AI & Data Services',
      icon: '🧠',
      pages: [
        { title: 'Document Intelligence', url: '/document-intelligence', icon: '🔍' },
        { title: 'Microsoft Graph',       url: '/ms-graph',              icon: '🔗' },
        { title: 'AI Search',             url: '/ai-search',             icon: '🔎' }
      ]
    },
    {
      title: 'AI Agents',
      icon: '🤖',
      pages: [
        { title: 'Employee Copilot Agent', url: '/employee-agent', icon: '🤖' },
        { title: 'Agent Prompts (30)',      url: '/agent-prompts',  icon: '💬' },
        { title: 'Agent Packaging',        url: '/agent-package',  icon: '📦' }
      ]
    }
  ];
}
