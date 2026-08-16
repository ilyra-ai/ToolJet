import { INestApplicationContext } from '@nestjs/common';
import { NestFactory } from '@nestjs/core';
import { AppModule } from '@modules/app/module';
import { getImportPath } from '@modules/app/constants';
import { APP_TYPES } from '@modules/apps/constants';
import {
  DEFAULT_GROUP_PERMISSIONS,
  GROUP_PERMISSIONS_TYPE,
  ResourceType,
  USER_ROLE,
} from '@modules/group-permissions/constants';
import { DEFAULT_GRANULAR_PERMISSIONS_NAME } from '@modules/group-permissions/constants/granular_permissions';
import { OnboardingStatus } from '@modules/onboarding/constants';
import {
  SOURCE,
  USER_STATUS,
  USER_TYPE,
  WORKSPACE_STATUS,
  WORKSPACE_USER_SOURCE,
  WORKSPACE_USER_STATUS,
} from '@modules/users/constants/lifecycle';
import { AppsGroupPermissions } from '@entities/apps_group_permissions.entity';
import { DataSourcesGroupPermissions } from '@entities/data_sources_group_permissions.entity';
import { FoldersGroupPermissions } from '@entities/folders_group_permissions.entity';
import { GranularPermissions } from '@entities/granular_permissions.entity';
import { GroupPermissions } from '@entities/group_permissions.entity';
import { GroupUsers } from '@entities/group_users.entity';
import { Organization } from '@entities/organization.entity';
import { OrganizationUser } from '@entities/organization_user.entity';
import { User } from '@entities/user.entity';
import * as bcrypt from 'bcrypt';
import { EntityManager, MigrationInterface, QueryRunner } from 'typeorm';

const MIGRATION_NAME = 'SeedLocalEnterpriseAdmin1787000000000';
const DEFAULT_ADMIN_EMAIL = 'admin@admin.com';
const DEFAULT_ADMIN_PASSWORD = 'admin123#';

export class SeedLocalEnterpriseAdmin1787000000000 implements MigrationInterface {
  public async up(queryRunner: QueryRunner): Promise<void> {
    if (process.env.TOOLJET_SEED_ADMIN !== 'true') {
      console.log(`${MIGRATION_NAME}: TOOLJET_SEED_ADMIN is not enabled; skipping.`);
      return;
    }

    const manager = queryRunner.manager;
    const email = (process.env.TOOLJET_SEED_ADMIN_EMAIL || DEFAULT_ADMIN_EMAIL).trim().toLowerCase();
    const password = process.env.TOOLJET_SEED_ADMIN_PASSWORD || DEFAULT_ADMIN_PASSWORD;
    const passwordDigest = bcrypt.hashSync(password, 10);

    let nestApp: INestApplicationContext | undefined;

    try {
      let user = await manager.createQueryBuilder(User, 'user').where('LOWER(user.email) = :email', { email }).getOne();

      if (user) {
        await manager.update(User, user.id, {
          email,
          firstName: 'Local',
          lastName: 'Administrator',
          password: passwordDigest,
          status: USER_STATUS.ACTIVE,
          source: SOURCE.SIGNUP,
          onboardingStatus: OnboardingStatus.ONBOARDING_COMPLETED,
          userType: USER_TYPE.INSTANCE,
          passwordRetryCount: 0,
        });
        user = await manager.findOneByOrFail(User, { id: user.id });
      } else {
        const result = await manager.insert(User, {
          email,
          firstName: 'Local',
          lastName: 'Administrator',
          password: passwordDigest,
          status: USER_STATUS.ACTIVE,
          source: SOURCE.SIGNUP,
          onboardingStatus: OnboardingStatus.ONBOARDING_COMPLETED,
          userType: USER_TYPE.INSTANCE,
          passwordRetryCount: 0,
          createdAt: new Date(),
          updatedAt: new Date(),
        });
        user = await manager.findOneByOrFail(User, {
          id: result.identifiers[0].id,
        });
      }

      let organizations = await manager.find(Organization, {
        where: { status: WORKSPACE_STATUS.ACTIVE },
        order: { createdAt: 'ASC' },
      });

      if (organizations.length === 0) {
        nestApp = await NestFactory.createApplicationContext(await AppModule.register({ IS_GET_CONTEXT: true }));
        const importPath = await getImportPath(true);
        const { SetupOrganizationsUtilService } = await import(`${importPath}/setup-organization/util.service`);
        const setupOrganizationsUtilService = nestApp.get(SetupOrganizationsUtilService, { strict: false });

        const organization = await setupOrganizationsUtilService.create(
          {
            name: process.env.TOOLJET_SEED_WORKSPACE_NAME || 'Local Enterprise',
            slug: process.env.TOOLJET_SEED_WORKSPACE_SLUG || 'local-enterprise',
            isDefault: true,
          },
          user,
          manager
        );
        organizations = [organization];
      }

      const defaultOrganization = organizations.find((organization) => organization.isDefault) || organizations[0];
      if (!defaultOrganization.isDefault) {
        await manager.update(Organization, defaultOrganization.id, {
          isDefault: true,
        });
      }
      await manager.update(User, user.id, {
        defaultOrganizationId: defaultOrganization.id,
      });

      for (const organization of organizations) {
        const adminGroup = await this.ensureAdminGroup(manager, organization.id);
        await this.ensureAdminGranularPermissions(manager, adminGroup.id);
        await this.ensureWorkspaceMembership(manager, user.id, organization.id);
        await this.ensureAdminRole(manager, user.id, organization.id, adminGroup.id);
      }

      console.log(
        `${MIGRATION_NAME}: ${email} is active as instance administrator in ${organizations.length} workspace(s).`
      );
    } finally {
      await nestApp?.close();
    }
  }

  private async ensureAdminGroup(manager: EntityManager, organizationId: string): Promise<GroupPermissions> {
    let adminGroup = await manager.findOne(GroupPermissions, {
      where: {
        organizationId,
        name: USER_ROLE.ADMIN,
        type: GROUP_PERMISSIONS_TYPE.DEFAULT,
      },
    });

    const permissions = DEFAULT_GROUP_PERMISSIONS.ADMIN;
    if (!adminGroup) {
      adminGroup = await manager.save(
        GroupPermissions,
        manager.create(GroupPermissions, {
          ...permissions,
          organizationId,
        })
      );
    } else {
      await manager.update(GroupPermissions, adminGroup.id, {
        appCreate: true,
        appDelete: true,
        workflowCreate: true,
        workflowDelete: true,
        folderCreate: true,
        folderDelete: true,
        moduleCreate: true,
        moduleDelete: true,
        orgConstantCRUD: true,
        tjdbCRUD: true,
        dataSourceCreate: true,
        dataSourceDelete: true,
        appPromote: true,
        appRelease: true,
      });
      adminGroup = await manager.findOneByOrFail(GroupPermissions, {
        id: adminGroup.id,
      });
    }

    return adminGroup;
  }

  private async ensureAdminGranularPermissions(manager: EntityManager, groupId: string): Promise<void> {
    for (const resourceType of Object.values(ResourceType)) {
      let granularPermission = await manager.findOne(GranularPermissions, {
        where: { groupId, type: resourceType },
      });

      if (!granularPermission) {
        granularPermission = await manager.save(
          GranularPermissions,
          manager.create(GranularPermissions, {
            groupId,
            type: resourceType,
            name: DEFAULT_GRANULAR_PERMISSIONS_NAME[resourceType],
            isAll: true,
          })
        );
      } else if (!granularPermission.isAll) {
        await manager.update(GranularPermissions, granularPermission.id, {
          isAll: true,
        });
      }

      switch (resourceType) {
        case ResourceType.APP:
          await this.ensureAppPermission(manager, granularPermission.id, APP_TYPES.FRONT_END);
          break;
        case ResourceType.WORKFLOWS:
          await this.ensureAppPermission(manager, granularPermission.id, APP_TYPES.WORKFLOW);
          break;
        case ResourceType.MODULE:
          await this.ensureAppPermission(manager, granularPermission.id, APP_TYPES.MODULE);
          break;
        case ResourceType.DATA_SOURCE:
          await this.ensureDataSourcePermission(manager, granularPermission.id);
          break;
        case ResourceType.FOLDER:
          await this.ensureFolderPermission(manager, granularPermission.id);
          break;
      }
    }
  }

  private async ensureAppPermission(
    manager: EntityManager,
    granularPermissionId: string,
    appType: APP_TYPES
  ): Promise<void> {
    const values = {
      appType,
      canEdit: true,
      canView: false,
      hideFromDashboard: false,
      canAccessDevelopment: true,
      canAccessStaging: true,
      canAccessProduction: true,
      canAccessReleased: true,
    };
    const existing = await manager.findOne(AppsGroupPermissions, {
      where: { granularPermissionId },
    });

    if (existing) {
      await manager.update(AppsGroupPermissions, existing.id, values);
    } else {
      await manager.insert(AppsGroupPermissions, {
        granularPermissionId,
        ...values,
      });
    }
  }

  private async ensureDataSourcePermission(manager: EntityManager, granularPermissionId: string): Promise<void> {
    const values = { canConfigure: true, canUse: true };
    const existing = await manager.findOne(DataSourcesGroupPermissions, {
      where: { granularPermissionId },
    });

    if (existing) {
      await manager.update(DataSourcesGroupPermissions, existing.id, values);
    } else {
      await manager.insert(DataSourcesGroupPermissions, {
        granularPermissionId,
        ...values,
      });
    }
  }

  private async ensureFolderPermission(manager: EntityManager, granularPermissionId: string): Promise<void> {
    const values = {
      canEditFolder: true,
      canEditApps: false,
      canViewApps: false,
    };
    const existing = await manager.findOne(FoldersGroupPermissions, {
      where: { granularPermissionId },
    });

    if (existing) {
      await manager.update(FoldersGroupPermissions, existing.id, values);
    } else {
      await manager.insert(FoldersGroupPermissions, {
        granularPermissionId,
        ...values,
      });
    }
  }

  private async ensureWorkspaceMembership(
    manager: EntityManager,
    userId: string,
    organizationId: string
  ): Promise<void> {
    const membership = await manager.findOne(OrganizationUser, {
      where: { userId, organizationId },
    });
    const values = {
      role: 'all-users',
      status: WORKSPACE_USER_STATUS.ACTIVE,
      source: WORKSPACE_USER_SOURCE.INVITE,
      invitationToken: null,
      invitationTokenExpiry: null,
    };

    if (membership) {
      await manager.update(OrganizationUser, membership.id, values);
    } else {
      await manager.insert(OrganizationUser, {
        userId,
        organizationId,
        ...values,
      });
    }
  }

  private async ensureAdminRole(
    manager: EntityManager,
    userId: string,
    organizationId: string,
    adminGroupId: string
  ): Promise<void> {
    await manager
      .createQueryBuilder()
      .delete()
      .from(GroupUsers)
      .where('user_id = :userId', { userId })
      .andWhere(
        `group_id IN (
          SELECT id FROM permission_groups
          WHERE organization_id = :organizationId
            AND type = :groupType
            AND name <> :adminRole
        )`,
        {
          organizationId,
          groupType: GROUP_PERMISSIONS_TYPE.DEFAULT,
          adminRole: USER_ROLE.ADMIN,
        }
      )
      .execute();

    const adminRole = await manager.findOne(GroupUsers, {
      where: { userId, groupId: adminGroupId },
    });
    if (!adminRole) {
      await manager.insert(GroupUsers, { userId, groupId: adminGroupId });
    }
  }

  public async down(): Promise<void> {}
}
