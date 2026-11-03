import http from "k6/http";
import { check } from "k6";

const BASE_URL = __ENV.BASE_URL || "https://dev.edgeboard.click";

export const options = {
  scenarios: {
    read_messages: {
      executor: "constant-arrival-rate", // Send requests at a fixed rate
      rate: 10, // 10 req/s (below the API's 20 req/s throttle)
      timeUnit: "1s",
      duration: "60s",
      preAllocatedVUs: 20, // Pre-allocate 20 virtual users
    },
  },
  // Pass/fail thresholds: k6 exits non-zero if any fails
  thresholds: {
    http_req_failed: ["rate<0.01"], // Error rate below 1%
    http_req_duration: ["p(99)<1000"], // P99 under 1 second
  },
  summaryTrendStats: ["avg", "med", "p(95)", "p(99)", "max"],
};

export default function () {
  const res = http.get(`${BASE_URL}/api/messages`);
  check(res, { "status is 200": (r) => r.status === 200 });
}
