import http from 'k6/http';
import { check, sleep } from 'k6';

// ============================================================================
// NotifyEd - 100% REAL LIVE MULTI-TARGET LOAD & STRESS TESTING SUITE (k6)
// Targets: 3 Core Live Database Modules with Independent Tagged Metrics
// ============================================================================

export const options = {
  stages: [
    { duration: '10s', target: 10 },  // Phase 1: 10 VUs - Nominal Baseline
    { duration: '15s', target: 50 },  // Phase 2: 50 VUs - Normal Simultaneous Traffic
    { duration: '15s', target: 100 }, // Phase 3: 100 VUs - Peak School Hours Encoding
    { duration: '15s', target: 200 }, // Phase 4: 200 VUs - Maximum Stress Breaking Limit
    { duration: '10s', target: 0 },   // Phase 5: Cool-down & System Recovery
  ],
  thresholds: {
    'http_req_failed': ['rate<0.01'],    // Total error rate must remain under 1%
    'http_req_duration': ['p(95)<3000'], // 95% of queries must resolve under 3.0s
    'http_req_duration{name:Student_Roster_Dashboard}': ['p(95)<2000'],
    'http_req_duration{name:NFC_Attendance_Sync}': ['p(95)<2000'],
    'http_req_duration{name:Grade_Records_At_Risk}': ['p(95)<2000'],
  },
};

const SUPABASE_URL = 'https://vslqselpnkpghtpnxryg.supabase.co';
const API_KEY = 'sb_publishable_qAfWW1fw67Xb85gAtWyBZg_sKB-ISaW';

export default function () {
  const baseHeaders = {
    'apikey': API_KEY,
    'Authorization': `Bearer ${API_KEY}`,
    'Content-Type': 'application/json',
  };

  // 1. Target Endpoint: Student Roster & Dashboard Fetch
  const resStudents = http.get(`${SUPABASE_URL}/rest/v1/students?select=*`, {
    headers: baseHeaders,
    tags: { name: 'Student_Roster_Dashboard' },
  });
  check(resStudents, {
    'Student Roster status is 200': (r) => r.status === 200,
  });

  // 2. Target Endpoint: NFC Attendance Real-Time Sync
  const resAttendance = http.get(`${SUPABASE_URL}/rest/v1/attendance?select=*&limit=50`, {
    headers: baseHeaders,
    tags: { name: 'NFC_Attendance_Sync' },
  });
  check(resAttendance, {
    'NFC Attendance status is 200': (r) => r.status === 200,
  });

  // 3. Target Endpoint: Grade Records & At-Risk Logic Evaluation
  const resScores = http.get(`${SUPABASE_URL}/rest/v1/scores?select=*&limit=50`, {
    headers: baseHeaders,
    tags: { name: 'Grade_Records_At_Risk' },
  });
  check(resScores, {
    'Grade Records status is 200': (r) => r.status === 200,
  });

  sleep(0.5);
}
