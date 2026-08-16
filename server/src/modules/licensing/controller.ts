import { Body, Controller, Get, Req, UseGuards } from '@nestjs/common';
import { ILicenseController } from './interfaces/IController';
import { Terms } from './interfaces/terms';
import { InitModule } from '@modules/app/decorators/init-module';
import { MODULES } from '@modules/app/constants/modules';
import { LicenseUpdateDto } from './dto';
import { FeatureAbilityGuard } from './ability/guard';
import { FEATURE_KEY } from './constants';
import { InitFeature } from '@modules/app/decorators/init-feature.decorator';
import { User as UserEntity } from '@entities/user.entity';
import { User } from '@modules/app/decorators/user.decorator';
import { UpdateEnvLicenseSettingDto } from '@modules/licensing/dto/update-env-license-setting.dto';
import { LICENSE_FIELD } from './constants';
import { LicenseTermsService } from './interfaces/IService';
import { isAllPlansEnabled } from './constants/PlanTerms';

@InitModule(MODULES.LICENSING)
@Controller('license')
export class LicenseController implements ILicenseController {
  constructor(protected readonly licenseTermsService: LicenseTermsService) {}

  getLicense(): Promise<any> {
    throw new Error('Method not implemented.');
  }

  @UseGuards(FeatureAbilityGuard)
  @InitFeature(FEATURE_KEY.GET_ACCESS)
  @Get('access')
  async getFeatureAccess(@Req() req: Request): Promise<Terms> {
    if (isAllPlansEnabled()) {
      const [features, licenseStatus, plan] = await Promise.all([
        this.licenseTermsService.getLicenseTermsInstance(LICENSE_FIELD.FEATURES),
        this.licenseTermsService.getLicenseTermsInstance(LICENSE_FIELD.STATUS),
        this.licenseTermsService.getLicenseTermsInstance(LICENSE_FIELD.PLAN),
      ]);

      return {
        expiry: licenseStatus.expiryDate,
        licenseStatus,
        plan,
        ...features,
      } as Terms;
    }

    return Promise.resolve({
      expiry: '',
      licenseStatus: {
        isLicenseValid: false,
        isExpired: false,
      },
      github: true,
      google: true,
    });
  }
  getDomains(@Req() req: Request): Promise<{ domains: any; licenseStatus: any }> {
    throw new Error('Method not implemented.');
  }
  getLicenseTerms(@Req() req: Request): Promise<{ terms: Terms }> {
    throw new Error('Method not implemented.');
  }
  updateLicense(licenseUpdateDto: LicenseUpdateDto, @User() user: UserEntity): Promise<void> {
    throw new Error('Method not implemented.');
  }
  async updateEnvLicenseSetting(@Body() dto: UpdateEnvLicenseSettingDto): Promise<void> {
    throw new Error('Method not implemented.');
  }
}
