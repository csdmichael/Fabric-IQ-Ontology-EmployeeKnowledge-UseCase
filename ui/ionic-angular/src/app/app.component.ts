import { Component } from '@angular/core';

@Component({
  selector: 'app-root',
  templateUrl: 'app.component.html',
  styleUrls: ['app.component.scss']
})
export class AppComponent {
  readonly pages = [
    { title: 'Data Sources', url: '/data-sources' },
    { title: 'Ingestion & Intelligence', url: '/ingestion-flow' },
    { title: 'Data Agent Prompts', url: '/agent-prompts' },
    { title: 'Agent Packaging', url: '/agent-package' }
  ];
}
