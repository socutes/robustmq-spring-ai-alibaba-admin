declare namespace DashboardAPI {
  interface PromptsStats {
    total: number;
    addedThisMonth: number;
  }

  interface PromptVersionsStats {
    total: number;
    releaseCount: number;
    preCount: number;
  }

  interface ExperimentStats {
    total: number;
    draftCount: number;
    runningCount: number;
    completedCount: number;
    failedCount: number;
    stoppedCount: number;
  }

  interface DatasetsStats {
    total: number;
  }

  interface EvaluatorsStats {
    total: number;
  }

  interface RecentActivityItem {
    eventType: string;
    entityKey: string;
    entityVersion: string | null;
    description: string;
    timestamp: number;
  }

  interface DashboardOverviewResult {
    prompts: PromptsStats;
    promptVersions: PromptVersionsStats;
    experiments: ExperimentStats;
    datasets: DatasetsStats;
    evaluators: EvaluatorsStats;
    recentActivity: RecentActivityItem[];
  }
}
