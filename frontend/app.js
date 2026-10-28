const visitsEl = document.getElementById("visits");
const form = document.getElementById("message-form");
const authorInput = document.getElementById("author");
const messageInput = document.getElementById("message");
const charCountEl = document.getElementById("char-count");
const submitBtn = document.getElementById("submit");
const formErrorEl = document.getElementById("form-error");
const listEl = document.getElementById("messages");
const listErrorEl = document.getElementById("list-error");
const loadMoreBtn = document.getElementById("load-more");

const MAX_MESSAGE_LEN = 500;
let nextCursor = null;

// 统一的 API 调用：同源请求，直接写相对路径 /api/...
async function api(path, options = {}) {
  const headers = options.body ? { "Content-Type": "application/json" } : {};
  const resp = await fetch(path, { ...options, headers });
  const data = await resp.json().catch(() => ({}));
  if (!resp.ok) {
    // 我们的 Lambda 返回 {error}，API Gateway 自身（如 429）返回 {message}
    throw new Error(data.error || data.message || `HTTP ${resp.status}`);
  }
  return data;
}

// ⚠️ 安全关键：所有用户内容都用 textContent 写入，绝不使用 innerHTML
function renderMessage(m) {
  const li = document.createElement("li");

  const meta = document.createElement("div");
  meta.className = "meta";

  const author = document.createElement("strong");
  author.textContent = m.author;

  const time = document.createElement("time");
  time.dateTime = m.created_at;
  time.textContent = new Date(m.created_at).toLocaleString("zh-CN");

  meta.append(author, time);

  const body = document.createElement("p");
  body.textContent = m.message;

  li.append(meta, body);
  return li;
}

async function countVisit() {
  try {
    const data = await api("/api/visit", { method: "POST" });
    visitsEl.textContent = data.visits.toLocaleString("zh-CN");
  } catch {
    visitsEl.textContent = "—";
  }
}

async function loadMessages() {
  loadMoreBtn.disabled = true;
  listErrorEl.textContent = "";
  try {
    const query = nextCursor ? `?cursor=${encodeURIComponent(nextCursor)}` : "";
    const data = await api(`/api/messages${query}`);
    for (const m of data.messages) {
      listEl.append(renderMessage(m));
    }
    nextCursor = data.next_cursor;
  } catch (err) {
    listErrorEl.textContent = `加载失败：${err.message}`;
  } finally {
    loadMoreBtn.disabled = false;
    loadMoreBtn.hidden = !nextCursor;
  }
}

function updateCharCount() {
  charCountEl.textContent = `${messageInput.value.length} / ${MAX_MESSAGE_LEN}`;
}

form.addEventListener("submit", async (event) => {
  event.preventDefault(); // 阻止浏览器默认的"提交表单并刷新页面"
  formErrorEl.textContent = "";
  submitBtn.disabled = true; // 防止重复点击，导致发布两次
  try {
    const m = await api("/api/messages", {
      method: "POST",
      body: JSON.stringify({ author: authorInput.value, message: messageInput.value }),
    });
    listEl.prepend(renderMessage(m)); // 新留言插到最前面
    messageInput.value = "";
    updateCharCount();
  } catch (err) {
    formErrorEl.textContent = `发布失败：${err.message}`;
  } finally {
    submitBtn.disabled = false;
  }
});

messageInput.addEventListener("input", updateCharCount);
loadMoreBtn.addEventListener("click", loadMessages);

countVisit();
loadMessages();
