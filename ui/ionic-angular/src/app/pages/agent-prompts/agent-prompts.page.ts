import { Component } from '@angular/core';

type Prompt = {
  id: number;
  category: string;
  text: string;
  icon: string;
};

@Component({
  selector: 'app-agent-prompts',
  templateUrl: './agent-prompts.page.html',
  styleUrls: ['./agent-prompts.page.scss']
})
export class AgentPromptsPage {
  description = '30 sample prompts for the Fabric IQ Data Agent — one-click copy and execute. Ask about contributors, projects, skills, and more.';

  copiedId: number | null = null;
  categoryFilter = '';

  readonly prompts: Prompt[] = [
    // Contributors & Performance
    { id: 1,  category: 'Contributors', icon: '🏆', text: 'Who are the top 5 contributors across the entire organization by contribution score?' },
    { id: 2,  category: 'Contributors', icon: '🏆', text: 'Who are the top contributors in the Manufacturing department?' },
    { id: 3,  category: 'Contributors', icon: '🏆', text: 'Which employees have a contribution score above 85 and are involved in more than 4 projects?' },
    { id: 4,  category: 'Contributors', icon: '🏆', text: 'List all star-tier contributors and their departments.' },
    { id: 5,  category: 'Contributors', icon: '🏆', text: 'Who has the most mentoring sessions across the company?' },
    // Employee Lookup
    { id: 6,  category: 'Employee Lookup', icon: '👤', text: 'What did Alex Garcia (EMP001) work on in the last year?' },
    { id: 7,  category: 'Employee Lookup', icon: '👤', text: 'Show me the full contribution profile for Jordan Nguyen including projects and digital assets.' },
    { id: 8,  category: 'Employee Lookup', icon: '👤', text: 'What skills does Riley Patel have and which projects are they contributing to?' },
    { id: 9,  category: 'Employee Lookup', icon: '👤', text: 'Which employees are located in Bengaluru and what is their average contribution score?' },
    { id: 10, category: 'Employee Lookup', icon: '👤', text: 'Who are the longest-tenured employees and how do their contribution scores compare?' },
    // Projects
    { id: 11, category: 'Projects', icon: '🗂️', text: 'Who is working on the NextGen Etch Process Automation project?' },
    { id: 12, category: 'Projects', icon: '🗂️', text: 'List all active projects in the IT department with their team sizes.' },
    { id: 13, category: 'Projects', icon: '🗂️', text: 'Which projects use Azure AI and MLOps skills and who leads them?' },
    { id: 14, category: 'Projects', icon: '🗂️', text: 'Which employee appears in the most projects across the organization?' },
    { id: 15, category: 'Projects', icon: '🗂️', text: 'Show me all completed projects and the employees who contributed to them.' },
    // Digital Assets
    { id: 16, category: 'Digital Assets', icon: '📂', text: 'Which employees have the most digital assets and what types are they?' },
    { id: 17, category: 'Digital Assets', icon: '📂', text: 'How many presentations has EMP003 (Taylor Miller) created?' },
    { id: 18, category: 'Digital Assets', icon: '📂', text: 'List all knowledge assets created by employees in the R&D department.' },
    { id: 19, category: 'Digital Assets', icon: '📂', text: 'Which employees have fewer than 6 digital assets and may need knowledge-sharing support?' },
    { id: 20, category: 'Digital Assets', icon: '📂', text: 'What is the total asset count breakdown by type across all employees?' },
    // Department Analytics
    { id: 21, category: 'Department Analytics', icon: '🏢', text: 'Compare average contribution scores across all departments.' },
    { id: 22, category: 'Department Analytics', icon: '🏢', text: 'Which department has the highest average number of projects per employee?' },
    { id: 23, category: 'Department Analytics', icon: '🏢', text: 'How many employees does each department have and what is their skill distribution?' },
    { id: 24, category: 'Department Analytics', icon: '🏢', text: 'Which departments have the most developing-tier contributors that may need support?' },
    { id: 25, category: 'Department Analytics', icon: '🏢', text: 'Show headcount and contribution score trends grouped by office location.' },
    // Skills & Ontology
    { id: 26, category: 'Skills & Ontology', icon: '🎓', text: 'Which employees have both Python and Azure AI skills and work in R&D?' },
    { id: 27, category: 'Skills & Ontology', icon: '🎓', text: 'What skills are most common across star-tier contributors?' },
    { id: 28, category: 'Skills & Ontology', icon: '🎓', text: 'Find employees skilled in Fabric and Power BI who could join the OneLake Semantic Layer project.' },
    // Manager & Copilot
    { id: 29, category: 'Manager Insights', icon: '👔', text: 'Generate a performance summary for EMP005 (Casey Lee) including improvement suggestions.' },
    { id: 30, category: 'Manager Insights', icon: '👔', text: 'Which employees in Engineering have not participated in any project and may need engagement?' }
  ];

  get categories(): string[] {
    return [...new Set(this.prompts.map((p) => p.category))];
  }

  get filtered(): Prompt[] {
    if (!this.categoryFilter) return this.prompts;
    return this.prompts.filter((p) => p.category === this.categoryFilter);
  }

  onCategoryFilter(value: string): void {
    this.categoryFilter = value;
  }

  copyPrompt(prompt: Prompt): void {
    navigator.clipboard.writeText(prompt.text).then(() => {
      this.copiedId = prompt.id;
      setTimeout(() => { this.copiedId = null; }, 2000);
    }).catch(() => {
      this.copiedId = prompt.id;
      setTimeout(() => { this.copiedId = null; }, 2000);
    });
  }
}
