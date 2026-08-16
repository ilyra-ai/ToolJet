import { getSubpath } from '@/_helpers/routes';
import { isString } from 'lodash';
import config from 'config';

const processErrorMessage = (error) => {
  if (isString(error)) {
    return error;
  }
  return error?.error || 'Something went wrong. Please try again.';
};

function clearPageHistory() {
  const subpath = getSubpath() || '';
  history.replaceState(null, null, `${subpath}/`);
}

const fetchEdition = () => {
  return config.TOOLJET_EDITION?.toLowerCase() || 'ce';
};

const isAllPlansEnabled = () => String(config.TOOLJET_UNLOCK_ALL_PLANS).toLowerCase() === 'true';

const isWorkflowsFeatureEnabled = () => {
  const edition = fetchEdition();
  return isAllPlansEnabled() || edition === 'ee';
};

export { processErrorMessage, clearPageHistory, fetchEdition, isAllPlansEnabled, isWorkflowsFeatureEnabled };
