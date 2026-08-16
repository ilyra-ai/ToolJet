import { LICENSE_LIMIT, LICENSE_FIELD, LICENSE_TYPE } from '@modules/licensing/constants';
import { Terms } from '@modules/licensing/interfaces/terms';

export const BASIC_PLAN_TERMS: Partial<Terms> = {
  apps: LICENSE_LIMIT.UNLIMITED,
  workspaces: LICENSE_LIMIT.UNLIMITED,
  users: {
    total: LICENSE_LIMIT.UNLIMITED,
    editor: LICENSE_LIMIT.UNLIMITED,
    viewer: LICENSE_LIMIT.UNLIMITED,
    superadmin: 1,
  },
  database: {
    table: LICENSE_LIMIT.UNLIMITED,
  },
  features: {
    auditLogs: false,
    oidc: false,
    saml: false,
    customStyling: false,
    ldap: false,
    whiteLabelling: false,
    multiEnvironment: false,
    multiPlayerEdit: false,
    gitSync: false,
    comments: false,
    customThemes: false,
    serverSideGlobalResolve: false,
    queryFolders: false,
    scim: false,
    observability: false,
  },
  domains: [],
  workflows: {
    execution_timeout: 60,
    workspace: {
      total: 200,
      daily_executions: 500,
      monthly_executions: 10000,
    },
    instance: {
      total: 1000,
      daily_executions: 25000,
      monthly_executions: 50000,
    },
  },
  auditLogs: {
    maximumDays: 0,
  },
  app: {
    pages: {
      enabled: false,
      count: '',
      features: {
        appHeaderAndLogo: false,
        addNavGroup: false,
        canvasPageHeader: false,
        canvasPageFooter: false,
      },
    },
    permissions: {
      component: false,
      query: false,
      pages: false,
    },
    features: {
      promote: false,
      release: false,
      history: false,
      jsLibraries: false,
    },
  },
  modules: {
    enabled: false,
  },
  permissions: {
    customGroups: false,
  },
  observability: {
    enabled: false,
  },
};

/**
 * Explicit local license override used to exercise every plan-gated
 * capability that is available in this checkout. Docker Compose binds the
 * application to localhost when this override is enabled.
 */
export const DEVELOPMENT_ALL_PLANS_TERMS: Partial<Terms> = {
  ...BASIC_PLAN_TERMS,
  expiry: '2099-12-31',
  type: LICENSE_TYPE.ENTERPRISE,
  plan: {
    name: LICENSE_TYPE.ENTERPRISE,
    isFlexible: false,
  },
  features: {
    auditLogs: true,
    oidc: true,
    saml: true,
    customStyling: true,
    ldap: true,
    whiteLabelling: true,
    appWhiteLabelling: true,
    multiEnvironment: true,
    multiPlayerEdit: true,
    gitSync: true,
    workspaceEnv: true,
    comments: true,
    customThemes: true,
    serverSideGlobalResolve: true,
    queryFolders: true,
    scim: true,
    observability: true,
    ai: true,
    externalApi: true,
    customDomains: true,
    google: true,
    github: true,
  },
  workflows: {
    enabled: true,
    execution_timeout: 60,
    workspace: {
      total: LICENSE_LIMIT.UNLIMITED,
      daily_executions: LICENSE_LIMIT.UNLIMITED,
      monthly_executions: LICENSE_LIMIT.UNLIMITED,
    },
    instance: {
      total: LICENSE_LIMIT.UNLIMITED,
      daily_executions: LICENSE_LIMIT.UNLIMITED,
      monthly_executions: LICENSE_LIMIT.UNLIMITED,
    },
  },
  auditLogs: {
    maximumDays: 30,
  },
  app: {
    pages: {
      enabled: true,
      count: LICENSE_LIMIT.UNLIMITED,
      features: {
        appHeaderAndLogo: true,
        addNavGroup: true,
        canvasPageHeader: true,
        canvasPageFooter: true,
      },
    },
    permissions: {
      component: true,
      query: true,
      pages: true,
    },
    features: {
      promote: true,
      release: true,
      history: true,
      jsLibraries: true,
    },
  },
  modules: {
    enabled: true,
  },
  permissions: {
    customGroups: true,
  },
  observability: {
    enabled: true,
  },
  ai: {
    plan: 'credits',
  },
};

export const isAllPlansEnabled = (): boolean =>
  process.env.TOOLJET_UNLOCK_ALL_PLANS === 'true' || process.env.TOOLJET_DEV_UNLOCK_ALL_PLANS === 'true';

export const BASIC_PLAN_SETTINGS = {
  ALLOW_PERSONAL_WORKSPACE: {
    value: 'false',
  },
  WHITE_LABEL_LOGO: {
    value: '',
    feature: LICENSE_FIELD.WHITE_LABEL,
  },
  WHITE_LABEL_TEXT: {
    value: '',
    feature: LICENSE_FIELD.WHITE_LABEL,
  },
  WHITE_LABEL_FAVICON: {
    value: '',
    feature: LICENSE_FIELD.WHITE_LABEL,
  },
  ENABLE_MULTIPLAYER_EDITING: {
    value: 'false',
  },
  ENABLE_COMMENTS: {
    value: 'false',
  },
};

export const CLOUD_EDITION_SETTINGS = {
  ALLOW_PERSONAL_WORKSPACE: {
    value: 'true',
  },
  ENABLE_MULTIPLAYER_EDITING: {
    value: 'true',
  },
  ENABLE_COMMENTS: {
    value: 'true',
  },
  ENABLE_WORKSPACE_LOGIN_CONFIGURATION: {
    value: 'true',
  },
  SMTP_ENV_CONFIGURED: {
    value: 'true',
  },
  ENABLE_SIGNUP: {
    value: 'true',
  },
};

export const BUSINESS_PLAN_TERMS = {
  auditLogs: {
    maximumDays: 14,
  },
};

export const ENTERPRISE_PLAN_TERMS = {
  auditLogs: {
    maximumDays: 30,
  },
};

export const WORKFLOW_TEAM_PLAN_TERMS: Partial<Terms> = {
  workflows: {
    execution_timeout: 60,
    instance: {
      total: LICENSE_LIMIT.UNLIMITED,
      daily_executions: LICENSE_LIMIT.UNLIMITED,
      monthly_executions: LICENSE_LIMIT.UNLIMITED,
    },
    //Only sending instance not workspace
  },
};
