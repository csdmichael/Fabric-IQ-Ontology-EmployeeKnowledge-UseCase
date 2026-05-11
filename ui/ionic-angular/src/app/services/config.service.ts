export interface EndpointConfig {
  azure: Record<string, string>;
  microsoftFabric: Record<string, string>;
  integration: Record<string, string>;
}

export class ConfigService {
  configPath = '/api/config/endpoints';
  private cachedConfig?: EndpointConfig;

  async loadConfig(): Promise<EndpointConfig> {
    if (this.cachedConfig) {
      return this.cachedConfig;
    }

    try {
      const response = await fetch(this.configPath);
      if (!response.ok) {
        throw new Error(`Config request failed: ${response.status} ${response.statusText}`);
      }
      this.cachedConfig = (await response.json()) as EndpointConfig;
      return this.cachedConfig;
    } catch (error) {
      throw new Error(`Unable to load endpoint configuration from ${this.configPath}: ${String(error)}`);
    }
  }
}
