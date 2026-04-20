# Component Patterns Reference

> Load this file when implementing complex component architectures. Framework-agnostic patterns with React examples — use Context7 for framework-specific APIs.

## Container / Presentational Split

**When:** A component mixes data fetching with rendering.

```tsx
// Container: handles data + logic
function UserProfileContainer({ userId }: { userId: string }) {
  const { data, isLoading, error } = useQuery(['user', userId], () => fetchUser(userId));

  if (isLoading) return <ProfileSkeleton />;
  if (error) return <ErrorCard message="Failed to load profile" retry={() => refetch()} />;
  return <UserProfileDisplay user={data} />;
}

// Presentational: pure rendering, easy to test
function UserProfileDisplay({ user }: { user: User }) {
  return (
    <article className="profile">
      <Avatar src={user.avatar} alt={user.name} size="lg" />
      <h2>{user.name}</h2>
      <p>{user.bio}</p>
    </article>
  );
}
```

**Pitfalls:**
- Don't split prematurely — a single component is fine until complexity demands separation
- Don't create containers that just pass all props through (pointless indirection)
- The split is about separation of concerns, not about file count

## Compound Components

**When:** A set of components work together as a unit (tabs, accordion, dropdown, form).

```tsx
// Usage — components share implicit state
<Tabs defaultTab="settings">
  <Tabs.List>
    <Tabs.Tab id="profile">Profile</Tabs.Tab>
    <Tabs.Tab id="settings">Settings</Tabs.Tab>
  </Tabs.List>
  <Tabs.Panel id="profile"><ProfileForm /></Tabs.Panel>
  <Tabs.Panel id="settings"><SettingsForm /></Tabs.Panel>
</Tabs>

// Implementation — context connects the pieces
const TabsContext = createContext<TabsState | null>(null);

function Tabs({ defaultTab, children }: TabsProps) {
  const [activeTab, setActiveTab] = useState(defaultTab);
  return (
    <TabsContext.Provider value={{ activeTab, setActiveTab }}>
      <div role="tablist">{children}</div>
    </TabsContext.Provider>
  );
}

Tabs.Tab = function Tab({ id, children }: TabProps) {
  const { activeTab, setActiveTab } = useContext(TabsContext)!;
  return (
    <button
      role="tab"
      aria-selected={activeTab === id}
      onClick={() => setActiveTab(id)}
    >
      {children}
    </button>
  );
};

Tabs.Panel = function Panel({ id, children }: PanelProps) {
  const { activeTab } = useContext(TabsContext)!;
  if (activeTab !== id) return null;
  return <div role="tabpanel">{children}</div>;
};
```

**Pitfalls:**
- Must validate that child components are used within the parent (throw if context is null)
- Don't overuse — simple parent-child props are fine for 2-3 related components
- Consider accessibility: compound components often need ARIA roles and keyboard navigation

## Custom Hooks / Composables

**When:** Logic is reused across multiple components, or a component's logic is complex enough to test separately.

```tsx
// Encapsulate complex logic in a hook
function useDebounce<T>(value: T, delay: number): T {
  const [debounced, setDebounced] = useState(value);

  useEffect(() => {
    const timer = setTimeout(() => setDebounced(value), delay);
    return () => clearTimeout(timer);
  }, [value, delay]);

  return debounced;
}

// Compose hooks for feature-specific logic
function useUserSearch(initialQuery = '') {
  const [query, setQuery] = useState(initialQuery);
  const debouncedQuery = useDebounce(query, 300);
  const { data, isLoading } = useQuery(
    ['users', 'search', debouncedQuery],
    () => searchUsers(debouncedQuery),
    { enabled: debouncedQuery.length >= 2 }
  );

  return { query, setQuery, results: data ?? [], isLoading };
}
```

**Rules:**
- Hook name starts with `use` (React) or follows framework convention
- A hook should do ONE thing — compose multiple hooks for complex features
- Hooks that return more than 3 values should return an object, not an array
- Test hooks independently from components (renderHook in Testing Library)

## Form Handling

### Controlled Forms (recommended for most cases)

```tsx
function SignupForm({ onSubmit }: { onSubmit: (data: SignupData) => void }) {
  const [formData, setFormData] = useState<SignupData>({ email: '', password: '' });
  const [errors, setErrors] = useState<Record<string, string>>({});
  const [isSubmitting, setIsSubmitting] = useState(false);

  const validate = (data: SignupData): Record<string, string> => {
    const errors: Record<string, string> = {};
    if (!data.email.includes('@')) errors.email = 'Invalid email';
    if (data.password.length < 8) errors.password = 'Min 8 characters';
    return errors;
  };

  const handleSubmit = async (e: FormEvent) => {
    e.preventDefault();
    const validationErrors = validate(formData);
    if (Object.keys(validationErrors).length > 0) {
      setErrors(validationErrors);
      return;
    }
    setIsSubmitting(true);
    try {
      await onSubmit(formData);
    } catch (err) {
      setErrors({ form: 'Submission failed. Please try again.' });
    } finally {
      setIsSubmitting(false);
    }
  };

  return (
    <form onSubmit={handleSubmit} noValidate>
      <label htmlFor="email">Email</label>
      <input
        id="email"
        type="email"
        value={formData.email}
        onChange={(e) => setFormData(prev => ({ ...prev, email: e.target.value }))}
        aria-invalid={!!errors.email}
        aria-describedby={errors.email ? 'email-error' : undefined}
      />
      {errors.email && <p id="email-error" role="alert">{errors.email}</p>}

      {/* Password field similar pattern */}

      <button type="submit" disabled={isSubmitting}>
        {isSubmitting ? 'Creating account...' : 'Sign up'}
      </button>
      {errors.form && <p role="alert">{errors.form}</p>}
    </form>
  );
}
```

**Consider form libraries when:** >5 fields, complex validation rules, dynamic fields, multi-step wizards. Use React Hook Form, Formik, or framework equivalent + Zod/Yup for schema validation.

## Data Fetching Patterns

### Loading / Error / Success States

Every data-fetching component needs three states:

```tsx
function UserList() {
  const { data, isLoading, error, refetch } = useQuery(['users'], fetchUsers);

  if (isLoading) return <UserListSkeleton count={5} />;  // Skeleton, not spinner
  if (error) return (
    <ErrorCard
      message="Failed to load users"
      action={<button onClick={() => refetch()}>Retry</button>}
    />
  );
  if (data.length === 0) return (
    <EmptyState
      icon={<UsersIcon />}
      title="No users yet"
      action={<Link to="/invite">Invite your first user</Link>}
    />
  );

  return <ul>{data.map(user => <UserCard key={user.id} user={user} />)}</ul>;
}
```

### Optimistic Updates

```tsx
const mutation = useMutation(updateTodo, {
  onMutate: async (updatedTodo) => {
    await queryClient.cancelQueries(['todos']);
    const previous = queryClient.getQueryData<Todo[]>(['todos']);
    queryClient.setQueryData<Todo[]>(['todos'], old =>
      old?.map(t => t.id === updatedTodo.id ? { ...t, ...updatedTodo } : t) ?? []
    );
    return { previous };
  },
  onError: (_err, _todo, context) => {
    queryClient.setQueryData(['todos'], context?.previous);  // Rollback
    toast.error('Failed to update. Reverted.');
  },
  onSettled: () => queryClient.invalidateQueries(['todos']),  // Refetch
});
```

**Use optimistic updates for:** Toggle actions (like/unlike), status changes, reordering. Don't use for creates (you don't have an ID yet) unless you generate client-side IDs.

## Routing Patterns

### Protected Routes

```tsx
function ProtectedRoute({ children }: { children: ReactNode }) {
  const { user, isLoading } = useAuth();
  const location = useLocation();

  if (isLoading) return <FullPageSpinner />;
  if (!user) return <Navigate to="/login" state={{ from: location }} replace />;
  return <>{children}</>;
}

// Usage
<Route path="/dashboard" element={<ProtectedRoute><Dashboard /></ProtectedRoute>} />
```

### Layout Routes

```tsx
// Shared layout wraps child routes
<Route element={<AppLayout />}>
  <Route path="/dashboard" element={<Dashboard />} />
  <Route path="/settings" element={<Settings />} />
  <Route path="/profile" element={<Profile />} />
</Route>

function AppLayout() {
  return (
    <div className="app-layout">
      <Sidebar />
      <main>
        <Outlet />  {/* Child route renders here */}
      </main>
    </div>
  );
}
```

### Code Splitting by Route

```tsx
const Dashboard = lazy(() => import('./pages/Dashboard'));
const Settings = lazy(() => import('./pages/Settings'));

<Suspense fallback={<PageSkeleton />}>
  <Routes>
    <Route path="/dashboard" element={<Dashboard />} />
    <Route path="/settings" element={<Settings />} />
  </Routes>
</Suspense>
```

## Error Boundaries

**Place error boundaries at feature boundaries**, not around every component.

```tsx
class ErrorBoundary extends Component<Props, State> {
  state = { hasError: false, error: null };

  static getDerivedStateFromError(error: Error) {
    return { hasError: true, error };
  }

  componentDidCatch(error: Error, info: ErrorInfo) {
    reportError(error, info);  // Send to error tracking service
  }

  render() {
    if (this.state.hasError) {
      return this.props.fallback ?? (
        <ErrorCard
          message="Something went wrong"
          action={<button onClick={() => this.setState({ hasError: false })}>Try again</button>}
        />
      );
    }
    return this.props.children;
  }
}

// Usage — wrap feature sections, not individual components
<ErrorBoundary fallback={<DashboardError />}>
  <Dashboard />
</ErrorBoundary>
```

**Where to place:**
- Around each major page/feature section
- Around third-party components you don't control
- Around data visualization/chart components
- NOT around every small component (overhead, confusing UX)

## Component Size Guidelines

| Lines | Action |
|-------|--------|
| <100 | Probably fine as-is |
| 100-200 | Review — can logic be extracted to hooks? |
| 200-300 | Likely needs splitting — find natural boundaries |
| >300 | Definitely split — this is doing too many things |

**When splitting, extract by concept:**
- Data fetching → custom hook
- Complex calculations → utility function
- Repeated UI patterns → presentational component
- State machine logic → useReducer or state library
- Side effects → custom hook with cleanup
