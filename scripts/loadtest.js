import http from "k6/http";
import { check } from "k6";

const BASE_URL = __ENV.BASE_URL || "https://dev.edgeboard.click";

export const options = {
  scenarios: {
    read_messages: {
      executor: "constant-arrival-rate", // 严格按固定速率发送请求
      rate: 10, // 每秒 10 个请求（低于 API 限流的每秒 20 个）
      timeUnit: "1s",
      duration: "60s",
      preAllocatedVUs: 20, // 预先准备 20 个"虚拟用户"
    },
  },
  // 质量门槛：任何一项不满足，k6 就以非 0 退出码结束
  thresholds: {
    http_req_failed: ["rate<0.01"], // 失败率低于 1%
    http_req_duration: ["p(99)<1000"], // P99 低于 1 秒
  },
  summaryTrendStats: ["avg", "med", "p(95)", "p(99)", "max"],
};

export default function () {
  const res = http.get(`${BASE_URL}/api/messages`);
  check(res, { "status is 200": (r) => r.status === 200 });
}
