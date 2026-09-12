const API_BASE = "/api";

// --- Health check ---
async function checkHealth() {
    const badge = document.getElementById("health-badge");
    try {
        const res = await fetch(`${API_BASE}/health`);
        if (res.ok) {
            badge.textContent = "Healthy";
            badge.className = "badge badge-healthy";
        } else {
            badge.textContent = "Unhealthy";
            badge.className = "badge badge-unhealthy";
        }
    } catch {
        badge.textContent = "Unreachable";
        badge.className = "badge badge-unhealthy";
    }
}

// --- Load items ---
async function loadItems() {
    const loading = document.getElementById("loading");
    const table = document.getElementById("items-table");
    const noItems = document.getElementById("no-items");
    const tbody = document.getElementById("items-body");
    const count = document.getElementById("item-count");

    loading.hidden = false;
    table.hidden = true;
    noItems.hidden = true;

    try {
        const res = await fetch(`${API_BASE}/items`);
        const items = await res.json();

        loading.hidden = true;
        tbody.innerHTML = "";

        if (items.length === 0) {
            noItems.hidden = false;
            count.textContent = "";
            return;
        }

        count.textContent = `(${items.length})`;
        table.hidden = false;

        items.forEach((item) => {
            const tr = document.createElement("tr");
            const created = item.created_at
                ? new Date(item.created_at).toLocaleString()
                : "-";
            tr.innerHTML = `
                <td>${item.id}</td>
                <td>${escapeHtml(item.name)}</td>
                <td>${escapeHtml(item.description || "-")}</td>
                <td>${created}</td>
                <td><button class="btn btn-danger" onclick="deleteItem(${item.id})">Delete</button></td>
            `;
            tbody.appendChild(tr);
        });
    } catch (err) {
        loading.hidden = true;
        showMessage(`Failed to load items: ${err.message}`, "error");
    }
}

// --- Add item ---
document.getElementById("item-form").addEventListener("submit", async (e) => {
    e.preventDefault();
    const name = document.getElementById("name").value.trim();
    const description = document.getElementById("description").value.trim();

    if (!name) return;

    try {
        const res = await fetch(`${API_BASE}/items`, {
            method: "POST",
            headers: { "Content-Type": "application/json" },
            body: JSON.stringify({ name, description }),
        });

        if (res.ok) {
            document.getElementById("item-form").reset();
            showMessage("Item added successfully!", "success");
            loadItems();
        } else {
            const data = await res.json();
            showMessage(data.error || "Failed to add item", "error");
        }
    } catch (err) {
        showMessage(`Error: ${err.message}`, "error");
    }
});

// --- Delete item ---
async function deleteItem(id) {
    if (!confirm("Delete this item?")) return;

    try {
        const res = await fetch(`${API_BASE}/items/${id}`, { method: "DELETE" });
        if (res.ok) {
            showMessage("Item deleted", "success");
            loadItems();
        } else {
            showMessage("Failed to delete item", "error");
        }
    } catch (err) {
        showMessage(`Error: ${err.message}`, "error");
    }
}

// --- Helpers ---
function showMessage(text, type) {
    const el = document.getElementById("form-message");
    el.textContent = text;
    el.className = `message message-${type}`;
    el.hidden = false;
    setTimeout(() => {
        el.hidden = true;
    }, 3000);
}

function escapeHtml(str) {
    const div = document.createElement("div");
    div.textContent = str;
    return div.innerHTML;
}

// --- Init ---
checkHealth();
loadItems();
setInterval(checkHealth, 30000);
