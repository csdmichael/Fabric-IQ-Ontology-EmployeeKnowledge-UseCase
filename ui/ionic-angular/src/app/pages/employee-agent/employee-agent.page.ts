import { Component } from '@angular/core';

type Employee = {
  employeeId: string;
  displayName: string;
  department: string;
  role: string;
  location: string;
  skills: string[];
  hireDate: string;
};

type Contribution = {
  employeeId: string;
  department: string;
  projectIds: string[];
  projectCount: number;
  activeProjectCount: number;
  completedProjectCount: number;
  assetCount: number;
  presentationCount: number;
  documentCount: number;
  reportCount: number;
  emailActivityCount: number;
  mentoringSessionCount: number;
  codeCommitCount: number;
  contributionScore: number;
  tier: string;
};

type AgentSummary = {
  headline: string;
  performanceSummary: string;
  strengths: string[];
  improvementAreas: string[];
  managerNotes: string;
  suggestedLearning: string[];
  recognitionSuggestion: string;
};

@Component({
  selector: 'app-employee-agent',
  templateUrl: './employee-agent.page.html',
  styleUrls: ['./employee-agent.page.scss']
})
export class EmployeeAgentPage {
  description = 'Copilot-powered performance summaries for each employee. Select an employee to read AI-generated insights, strengths, improvement suggestions, and manager notes.';

  employees: Employee[] = [];
  contributions: Contribution[] = [];

  selectedEmployeeId = '';
  isGenerating = false;
  agentSummary?: AgentSummary;

  loadError = '';

  constructor() {
    this.initialize().catch((err: unknown) => {
      this.loadError = `Unable to load employee data: ${err instanceof Error ? err.message : String(err)}`;
    });
  }

  async initialize(): Promise<void> {
    const [employees, contributions] = await Promise.all([
      this.readJson<Employee[]>('/data/employees.json'),
      this.readJson<Contribution[]>('/data/contributions.json')
    ]);
    this.employees = employees;
    this.contributions = contributions;
  }

  get selectedEmployee(): Employee | undefined {
    return this.employees.find((e) => e.employeeId === this.selectedEmployeeId);
  }

  get selectedContribution(): Contribution | undefined {
    return this.contributions.find((c) => c.employeeId === this.selectedEmployeeId);
  }

  onEmployeeChange(employeeId: string): void {
    this.selectedEmployeeId = employeeId;
    this.agentSummary = undefined;
    if (employeeId) {
      this.generateSummary();
    }
  }

  generateSummary(): void {
    const emp = this.selectedEmployee;
    const contrib = this.selectedContribution;
    if (!emp || !contrib) return;

    this.isGenerating = true;
    this.agentSummary = undefined;

    // Simulate async AI generation with a short delay
    setTimeout(() => {
      this.agentSummary = this.buildSummary(emp, contrib);
      this.isGenerating = false;
    }, 800);
  }

  private buildSummary(emp: Employee, contrib: Contribution): AgentSummary {
    const score = contrib.contributionScore;
    const tier = contrib.tier;

    const headline = tier === 'star'
      ? `${emp.displayName} is a standout contributor in ${emp.department}, consistently delivering high-impact work across multiple projects.`
      : tier === 'low'
      ? `${emp.displayName} shows growth potential in ${emp.department} with focused support and structured mentoring.`
      : `${emp.displayName} is a reliable contributor in ${emp.department}, maintaining steady output with opportunities to expand.`;

    const performanceSummary = this.buildPerformanceSummary(emp, contrib);
    const strengths = this.buildStrengths(emp, contrib);
    const improvementAreas = this.buildImprovements(contrib);
    const managerNotes = this.buildManagerNotes(emp, contrib);
    const suggestedLearning = this.buildLearning(emp, contrib);
    const recognitionSuggestion = this.buildRecognition(emp, contrib);

    return { headline, performanceSummary, strengths, improvementAreas, managerNotes, suggestedLearning, recognitionSuggestion };
  }

  private buildPerformanceSummary(emp: Employee, contrib: Contribution): string {
    const tenure = this.tenureYears(emp.hireDate);
    return `${emp.displayName} (${emp.role}, ${emp.department}) has been with the organization for approximately ${tenure} year${tenure !== 1 ? 's' : ''}, `
      + `contributing to ${contrib.projectCount} project${contrib.projectCount !== 1 ? 's' : ''} (${contrib.activeProjectCount} active, ${contrib.completedProjectCount} completed). `
      + `Their digital footprint includes ${contrib.assetCount} knowledge assets: ${contrib.presentationCount} presentations, `
      + `${contrib.documentCount} documents, and ${contrib.reportCount} reports. `
      + `Code commit volume is ${contrib.codeCommitCount}, email engagement is ${contrib.emailActivityCount}, `
      + `and they have facilitated ${contrib.mentoringSessionCount} mentoring sessions. `
      + `Overall contribution score: ${contrib.contributionScore}/100.`;
  }

  private buildStrengths(emp: Employee, contrib: Contribution): string[] {
    const strengths: string[] = [];
    if (contrib.projectCount >= 4) strengths.push(`Strong cross-project involvement across ${contrib.projectCount} initiatives, demonstrating broad organizational impact.`);
    if (contrib.mentoringSessionCount >= 8) strengths.push(`Exceptional mentoring commitment with ${contrib.mentoringSessionCount} sessions, supporting team capability growth.`);
    if (contrib.codeCommitCount >= 50) strengths.push(`High technical productivity with ${contrib.codeCommitCount} code commits, reflecting consistent engineering delivery.`);
    if (contrib.presentationCount >= 5) strengths.push(`Strong communication skills evidenced by ${contrib.presentationCount} presentations to stakeholders.`);
    if (emp.skills.length >= 4) strengths.push(`Diverse skill set spanning ${emp.skills.join(', ')}, enabling cross-functional collaboration.`);
    if (contrib.assetCount >= 12) strengths.push(`Prolific knowledge creator with ${contrib.assetCount} digital assets, enriching the team's knowledge base.`);
    if (strengths.length === 0) strengths.push(`Demonstrates reliability and foundational contributions aligned with role expectations.`);
    return strengths.slice(0, 4);
  }

  private buildImprovements(contrib: Contribution): string[] {
    const items: string[] = [];
    if (contrib.projectCount <= 1) items.push('Expand project participation to gain cross-departmental experience and visibility.');
    if (contrib.mentoringSessionCount <= 2) items.push('Consider increasing mentoring engagement to build leadership skills and team influence.');
    if (contrib.codeCommitCount <= 15) items.push('Increase technical output through more frequent contributions to shared repositories.');
    if (contrib.assetCount <= 6) items.push('Invest in creating more knowledge assets (presentations, documents) to amplify knowledge sharing.');
    if (contrib.documentCount <= 2) items.push('Improve documentation habits to capture institutional knowledge and support knowledge transfer.');
    if (items.length === 0) items.push('Continue current trajectory; consider stretching into new skill areas or mentoring roles.');
    return items.slice(0, 3);
  }

  private buildManagerNotes(emp: Employee, contrib: Contribution): string {
    if (contrib.tier === 'star') {
      return `${emp.displayName} is performing at a senior level. Consider nominating for recognition programs or stretch assignments. `
        + `Ensure workload is sustainable given their broad involvement in ${contrib.projectCount} projects.`;
    }
    if (contrib.tier === 'low') {
      return `Schedule a structured 1:1 development conversation with ${emp.displayName}. `
        + `Identify specific blockers limiting project participation and asset creation. `
        + `Consider pairing with a senior mentor to accelerate growth. Review targets in next performance cycle.`;
    }
    return `${emp.displayName} is on track. Explore opportunities to deepen their involvement in active projects. `
      + `Encourage cross-functional collaboration and knowledge sharing through presentations or team showcases.`;
  }

  private buildLearning(emp: Employee, contrib: Contribution): string[] {
    const learning: string[] = [];
    if (!emp.skills.includes('Azure AI')) learning.push('Microsoft Azure AI Foundry Fundamentals certification');
    if (!emp.skills.includes('Fabric')) learning.push('Microsoft Fabric Analytics Engineer Associate certification');
    if (!emp.skills.includes('Power BI')) learning.push('PL-300: Microsoft Power BI Data Analyst certification');
    if (contrib.mentoringSessionCount < 5) learning.push('Internal leadership & coaching workshop series');
    if (!emp.skills.includes('MLOps')) learning.push('MLOps and AI Operations on Azure learning path');
    learning.push(`${emp.department}-specific domain knowledge deepening via internal brown-bag sessions`);
    return learning.slice(0, 4);
  }

  private buildRecognition(emp: Employee, contrib: Contribution): string {
    if (contrib.tier === 'star') {
      return `Nominate ${emp.displayName} for the Quarterly Star Performer award and share their contributions in the all-hands meeting.`;
    }
    if (contrib.tier === 'average') {
      return `Acknowledge ${emp.displayName}'s consistent contributions in the next team meeting and encourage peer recognition.`;
    }
    return `Identify one recent win from ${emp.displayName} to highlight publicly, building confidence and motivation.`;
  }

  private tenureYears(hireDate: string): number {
    const hire = new Date(hireDate);
    const now = new Date();
    return Math.floor((now.getTime() - hire.getTime()) / (365.25 * 24 * 60 * 60 * 1000));
  }

  private async readJson<T>(url: string): Promise<T> {
    const response = await fetch(url);
    if (!response.ok) {
      throw new Error(`Failed to load ${url}: ${response.status} ${response.statusText}`);
    }
    return response.json() as Promise<T>;
  }
}
