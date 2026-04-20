# PTC Implementation Examples

## Complete Agent: Expense Budget Compliance

End-to-end example — checks N employees against budgets with custom exceptions.

### Tool Definitions

```python
tools = [
    {"type": "code_execution_20260120", "name": "code_execution"},
    {
        "name": "get_team_members",
        "description": "Returns team members as JSON array. Each: {id: string, name: string, role: string, department: string}",
        "input_schema": {
            "type": "object",
            "properties": {
                "department": {"type": "string", "description": "Department name (case-insensitive)"}
            },
            "required": ["department"],
        },
        "allowed_callers": ["code_execution_20260120"],
    },
    {
        "name": "get_expenses",
        "description": "Returns expense items as JSON array. Each: {id: string, employee_id: string, amount: float, category: string, status: string, date: string (ISO 8601)}",
        "input_schema": {
            "type": "object",
            "properties": {
                "employee_id": {"type": "string"},
                "quarter": {"type": "string", "enum": ["Q1", "Q2", "Q3", "Q4"]},
            },
            "required": ["employee_id", "quarter"],
        },
        "allowed_callers": ["code_execution_20260120"],
    },
    {
        "name": "get_custom_budget",
        "description": "Returns custom budget or null. Format: {user_id: string, budget: float | null, reason: string | null}",
        "input_schema": {
            "type": "object",
            "properties": {
                "user_id": {"type": "string"}
            },
            "required": ["user_id"],
        },
        "allowed_callers": ["code_execution_20260120"],
    },
]
```

### What Claude Generates (PTC code)

```python
import asyncio, json

async def main():
    # Step 1: Get all engineering members
    members = json.loads(await get_team_members({"department": "engineering"}))

    # Step 2: Parallel expense lookups
    expense_tasks = [
        get_expenses({"employee_id": m["id"], "quarter": "Q3"})
        for m in members
    ]
    raw_expenses = await asyncio.gather(*expense_tasks)

    # Step 3: Calculate travel totals (in code, not model context)
    DEFAULT_BUDGET = 5000
    over_budget = []
    for i, member in enumerate(members):
        expenses = json.loads(raw_expenses[i])
        travel_total = sum(
            e["amount"] for e in expenses
            if e["category"] == "travel" and e["status"] == "approved"
        )
        if travel_total > DEFAULT_BUDGET:
            over_budget.append({
                "member": member,
                "travel_total": travel_total,
            })

    # Step 4: Check custom budgets only for those over standard limit
    for entry in over_budget:
        custom = json.loads(await get_custom_budget({"user_id": entry["member"]["id"]}))
        entry["custom_budget"] = custom.get("budget")
        entry["truly_over"] = (
            entry["travel_total"] > entry["custom_budget"]
            if entry["custom_budget"]
            else True
        )

    # Step 5: Only print the violations (minimal context)
    violations = [e for e in over_budget if e["truly_over"]]
    print(f"Found {len(violations)} budget violations out of {len(members)} members:")
    for v in violations:
        limit = v["custom_budget"] or DEFAULT_BUDGET
        print(f"  {v['member']['name']}: ${v['travel_total']:,.0f} (limit: ${limit:,.0f})")

asyncio.run(main())
```

**Token savings**: 20 members × ~500 tokens per expense response = ~10,000 tokens kept out of context. Only the 2-3 line violation summary enters Claude's context.

## Complete Agent: Multi-Region Sales Analysis

### Tool Definition

```python
{
    "name": "query_sales",
    "description": "Query sales database. Returns JSON array of rows. Fields depend on query but commonly: {region: string, product: string, revenue: float, units: int, date: string}",
    "input_schema": {
        "type": "object",
        "properties": {
            "sql": {"type": "string", "description": "SQL SELECT query against sales table"}
        },
        "required": ["sql"],
    },
    "allowed_callers": ["code_execution_20260120"],
}
```

### Claude's Generated Code

```python
regions = ["West", "East", "Central", "North", "South"]
results = {}

for region in regions:
    data = json.loads(await query_sales({
        "sql": f"SELECT product, SUM(revenue) as total, COUNT(*) as orders FROM sales WHERE region='{region}' AND quarter='Q4' GROUP BY product ORDER BY total DESC"
    }))
    results[region] = {
        "total_revenue": sum(r["total"] for r in data),
        "top_product": data[0]["product"] if data else "N/A",
        "top_product_revenue": data[0]["total"] if data else 0,
        "product_count": len(data),
    }

# Rank regions
ranked = sorted(results.items(), key=lambda x: x[1]["total_revenue"], reverse=True)
print("Regional Performance (Q4):")
for i, (region, stats) in enumerate(ranked, 1):
    print(f"  {i}. {region}: ${stats['total_revenue']:,.0f} "
          f"({stats['product_count']} products, top: {stats['top_product']})")
```

## Alternative Implementations (Non-Anthropic)

### Client-Side Direct Execution

For environments that can safely execute code:

```python
import subprocess, json, tempfile

def execute_ptc_code(code: str, available_tools: dict) -> str:
    """Run Claude's code locally with tool functions injected."""
    # Inject tool implementations
    full_code = "\n".join([
        "import asyncio, json",
        *[inspect.getsource(fn) for fn in available_tools.values()],
        code,
    ])

    with tempfile.NamedTemporaryFile(mode="w", suffix=".py", delete=False) as f:
        f.write(full_code)
        result = subprocess.run(
            ["python", f.name],
            capture_output=True, text=True, timeout=30
        )
    return result.stdout
```

**Warning**: This executes untrusted code without sandboxing. Only use in controlled environments.

### Self-Managed Sandbox

For security-critical deployments, run in Docker/Firecracker with:
- No network egress (tools communicate via IPC/queue)
- Read-only filesystem
- CPU/memory limits
- Tool calls routed through a message broker

## Anti-Patterns

### Don't: Enable Both Callers Without Reason

```python
# BAD — confuses Claude about which path to use
"allowed_callers": ["direct", "code_execution_20260120"]

# GOOD — clear intent
"allowed_callers": ["code_execution_20260120"]  # Always via code
```

### Don't: Return Unstructured Text from PTC Tools

```python
# BAD — Claude can't parse in code
return "Found 3 results: Alice ($45K), Bob ($38K), Carol ($32K)"

# GOOD — Claude deserializes with json.loads()
return json.dumps([
    {"name": "Alice", "revenue": 45000},
    {"name": "Bob", "revenue": 38000},
    {"name": "Carol", "revenue": 32000},
])
```

### Don't: Include Text in Programmatic Tool Responses

```python
# BAD — API rejects this for programmatic tool calls
{"role": "user", "content": [
    {"type": "tool_result", "tool_use_id": "toolu_01", "content": "..."},
    {"type": "text", "text": "Here's additional context"},  # NOT ALLOWED
]}

# GOOD — only tool_result blocks
{"role": "user", "content": [
    {"type": "tool_result", "tool_use_id": "toolu_01", "content": "..."},
]}
```

### Don't: Ignore Container Expiry

```python
# BAD — no timeout handling
result = slow_database_query(sql)  # Takes 5 minutes
return result

# GOOD — implement client-side timeout
import asyncio
try:
    result = await asyncio.wait_for(slow_query(sql), timeout=60)
except asyncio.TimeoutError:
    return json.dumps({"error": "Query timed out after 60s"})
```
