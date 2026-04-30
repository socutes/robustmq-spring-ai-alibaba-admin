import { request } from '../../utils/request';
import { API_PATH } from '../const';

export async function getDashboardOverview() {
  return request<DashboardAPI.DashboardOverviewResult>(`${API_PATH}/dashboard/overview`, {
    method: 'GET',
  });
}
