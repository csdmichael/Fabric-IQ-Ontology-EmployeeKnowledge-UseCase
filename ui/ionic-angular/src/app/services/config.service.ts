export interface EndpointConfig {
  azure: Record<string, string>;
  microsoftFabric: Record<string, string>;
  integration: Record<string, string>;
}

export class ConfigService {
  configPath = '/config/endpoints.json';
  private cachedConfig?: EndpointConfig;

  async loadConfig(): Promise<EndpointConfig> {
    if (this.cachedConfig) {
      return this.cachedConfig;
    }

    const response = await fetch(this.configPath);
    this.cachedConfig = (await response.json()) as EndpointConfig;
    return this.cachedConfig;
  }
}
