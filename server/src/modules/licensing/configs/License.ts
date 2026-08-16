import LicenseBase from './LicenseBase';
import { BASIC_PLAN_TERMS, DEVELOPMENT_ALL_PLANS_TERMS, isAllPlansEnabled } from '../constants/PlanTerms';
import { LICENSE_TYPE } from '../constants';

export default class License extends LicenseBase {
  private static _instance: License;

  private constructor(key: string, updatedDate: Date) {
    super(
      isAllPlansEnabled() ? DEVELOPMENT_ALL_PLANS_TERMS : BASIC_PLAN_TERMS,
      isAllPlansEnabled() ? DEVELOPMENT_ALL_PLANS_TERMS : undefined,
      updatedDate,
      undefined,
      undefined,
      isAllPlansEnabled() ? LICENSE_TYPE.ENTERPRISE : undefined
    );
  }

  public static Instance(): License {
    return this._instance;
  }

  public static Reload(key: string, updatedDate: Date): License {
    return (this._instance = new this(key, updatedDate));
  }
}
