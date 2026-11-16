import http from 'k6/http';
import { check, sleep } from 'k6';

export const options = {
  stages: [
    { duration: '2m', target: 50 },
    { duration: '5m', target: 50 },
    { duration: '2m', target: 0 },
  ],
};

const BASE_URL = __ENV.BASE_URL || 'http://136.82.50.137';

export default function () {
  const payload = JSON.stringify({
    name: `Test Plane ${Math.random()}`,
    fuelCapacity: 1000,
    passengers: 10,
  });
  const params = {
    headers: { 'Content-Type': 'application/json' },
  };
  
  let res = http.post(`${BASE_URL}/planes`, payload, params);
  check(res, { 'POST status is 201': (r) => r.status === 201 });

  for (let i = 0; i < 8; i++) {
    res = http.get(`${BASE_URL}/planes`);
    check(res, { 'GET status is 200': (r) => r.status === 200 });
  }

  sleep(1);
}