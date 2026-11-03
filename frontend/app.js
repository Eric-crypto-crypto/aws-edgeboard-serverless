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

// Shared API helper: requests are same-origin, so relative /api/... paths work
async function api(path, options = {}) {
  const headers = options.body ? { "Content-Type": "application/json" } : {};
  const resp = await fetch(path, { ...options, headers });
  const data = await resp.json().catch(() => ({}));
  if (!resp.ok) {
    // Our Lambdas return {error}; API Gateway itself (e.g. 429) returns {message}
    throw new Error(data.error || data.message || `HTTP ${resp.status}`);
  }
  return data;
}

// ⚠️ Security-critical: always write user content with textContent, never innerHTML
function renderMessage(m) {
  const li = document.createElement("li");

  const meta = document.createElement("div");
  meta.className = "meta";

  const author = document.createElement("strong");
  author.textContent = m.author;

  const time = document.createElement("time");
  time.dateTime = m.created_at;
  time.textContent = new Date(m.created_at).toLocaleString();

  meta.append(author, time);

  const body = document.createElement("p");
  body.textContent = m.message;

  li.append(meta, body);
  return li;
}

async function countVisit() {
  try {
    const data = await api("/api/visit", { method: "POST" });
    visitsEl.textContent = data.visits.toLocaleString();
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
    listErrorEl.textContent = `Failed to load: ${err.message}`;
  } finally {
    loadMoreBtn.disabled = false;
    loadMoreBtn.hidden = !nextCursor;
  }
}

function updateCharCount() {
  charCountEl.textContent = `${messageInput.value.length} / ${MAX_MESSAGE_LEN}`;
}

form.addEventListener("submit", async (event) => {
  event.preventDefault(); // Stop the browser's default submit-and-reload
  formErrorEl.textContent = "";
  submitBtn.disabled = true; // Prevent double submits
  try {
    const m = await api("/api/messages", {
      method: "POST",
      body: JSON.stringify({ author: authorInput.value, message: messageInput.value }),
    });
    listEl.prepend(renderMessage(m)); // Newest message goes on top
    messageInput.value = "";
    updateCharCount();
  } catch (err) {
    formErrorEl.textContent = `Failed to post: ${err.message}`;
  } finally {
    submitBtn.disabled = false;
  }
});

messageInput.addEventListener("input", updateCharCount);
// Only fetch the next page; with no cursor, loadMessages() would re-fetch page 1
loadMoreBtn.addEventListener("click", () => {
  if (nextCursor) loadMessages();
});

countVisit();
loadMessages();
