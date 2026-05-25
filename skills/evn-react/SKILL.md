---
name: evn-react
description: React/TypeScript standards for EVN frontend applications - component structure, state management, hooks, and styling patterns
triggers:
  - react
  - typescript
  - frontend
  - component
  - hooks
  - state management
  - tsx
  - jsx
---

# EVN React/TypeScript Standards

React and TypeScript coding standards for EVN frontend applications.

## Core Principles

1. **Type Safety First** — No `any`, explicit types everywhere
2. **Functional Components** — Hooks over class components
3. **Composition Over Inheritance** — Small, reusable components
4. **Explicit Over Implicit** — Clear prop types, named exports
5. **Performance Aware** — Memoization, lazy loading, code splitting

## Project Structure

```
src/
├── components/              # Reusable UI components
│   ├── Button/
│   │   ├── Button.tsx
│   │   ├── Button.test.tsx
│   │   ├── Button.module.css
│   │   └── index.ts
│   └── Input/
│       ├── Input.tsx
│       └── index.ts
├── features/                # Feature-based modules
│   ├── auth/
│   │   ├── components/
│   │   ├── hooks/
│   │   ├── services/
│   │   └── types.ts
│   └── warehouse/
│       ├── components/
│       ├── hooks/
│       └── types.ts
├── hooks/                   # Shared custom hooks
│   ├── useAuth.ts
│   └── useFetch.ts
├── services/                # API clients
│   ├── api.ts
│   └── warehouse.ts
├── types/                   # Shared TypeScript types
│   ├── api.ts
│   └── models.ts
├── utils/                   # Utility functions
│   ├── format.ts
│   └── validation.ts
├── App.tsx
└── main.tsx
```

## Naming Conventions

### Files & Directories

- **PascalCase** — Components: `Button.tsx`, `UserProfile.tsx`
- **camelCase** — Hooks, utilities: `useAuth.ts`, `formatDate.ts`
- **kebab-case** — CSS modules: `button.module.css`

### Components

```tsx
// ✅ Correct — PascalCase, named export
export const Button = () => { ... }

// ❌ Wrong — default export
export default function Button() { ... }

// ❌ Wrong — camelCase
export const button = () => { ... }
```

### Hooks

```tsx
// ✅ Correct — camelCase, starts with "use"
export const useAuth = () => { ... }
export const useFetchWarehouse = () => { ... }

// ❌ Wrong — missing "use" prefix
export const auth = () => { ... }
```

### Types & Interfaces

```tsx
// ✅ Correct — PascalCase, descriptive
interface UserProfile {
  id: string;
  name: string;
}

type ButtonVariant = 'primary' | 'secondary';

// ❌ Wrong — prefixes
interface IUserProfile { ... }  // No "I" prefix
type TButtonVariant = ...       // No "T" prefix
```

## TypeScript Patterns

### Component Props

```tsx
// ✅ Correct — explicit interface
interface ButtonProps {
  variant?: 'primary' | 'secondary';
  size?: 'sm' | 'md' | 'lg';
  disabled?: boolean;
  onClick?: () => void;
  children: React.ReactNode;
}

export const Button = ({ 
  variant = 'primary',
  size = 'md',
  disabled = false,
  onClick,
  children 
}: ButtonProps) => {
  return (
    <button 
      className={`btn btn-${variant} btn-${size}`}
      disabled={disabled}
      onClick={onClick}
    >
      {children}
    </button>
  );
};

// ❌ Wrong — inline props, no types
export const Button = ({ variant, size, children }) => { ... }
```

### Event Handlers

```tsx
// ✅ Correct — explicit event types
const handleClick = (event: React.MouseEvent<HTMLButtonElement>) => {
  event.preventDefault();
  // ...
};

const handleChange = (event: React.ChangeEvent<HTMLInputElement>) => {
  setValue(event.target.value);
};

// ❌ Wrong — any type
const handleClick = (event: any) => { ... }
```

### State Types

```tsx
// ✅ Correct — explicit state types
const [user, setUser] = useState<User | null>(null);
const [loading, setLoading] = useState<boolean>(false);
const [items, setItems] = useState<Item[]>([]);

// ❌ Wrong — implicit any
const [user, setUser] = useState(null);
```

### API Response Types

```tsx
// ✅ Correct — typed responses
interface ApiResponse<T> {
  data: T;
  message: string;
  status: number;
}

interface User {
  id: string;
  name: string;
  email: string;
}

const fetchUser = async (id: string): Promise<ApiResponse<User>> => {
  const response = await fetch(`/api/users/${id}`);
  return response.json();
};

// ❌ Wrong — untyped
const fetchUser = async (id) => {
  const response = await fetch(`/api/users/${id}`);
  return response.json();
};
```

## Component Patterns

### Functional Components

```tsx
// ✅ Correct — arrow function, explicit return type
export const UserCard = ({ user }: { user: User }): JSX.Element => {
  return (
    <div className="user-card">
      <h3>{user.name}</h3>
      <p>{user.email}</p>
    </div>
  );
};

// Also acceptable — implicit return type
export const UserCard = ({ user }: { user: User }) => {
  return (
    <div className="user-card">
      <h3>{user.name}</h3>
      <p>{user.email}</p>
    </div>
  );
};
```

### Props with Children

```tsx
interface CardProps {
  title: string;
  children: React.ReactNode;
}

export const Card = ({ title, children }: CardProps) => {
  return (
    <div className="card">
      <h2>{title}</h2>
      <div className="card-content">{children}</div>
    </div>
  );
};
```

### Optional Props with Defaults

```tsx
interface ButtonProps {
  variant?: 'primary' | 'secondary';
  size?: 'sm' | 'md' | 'lg';
  children: React.ReactNode;
}

export const Button = ({ 
  variant = 'primary',
  size = 'md',
  children 
}: ButtonProps) => {
  return <button className={`btn-${variant} btn-${size}`}>{children}</button>;
};
```

### Conditional Rendering

```tsx
// ✅ Correct — explicit conditions
export const UserStatus = ({ user }: { user: User | null }) => {
  if (!user) {
    return <div>Loading...</div>;
  }

  if (user.isActive) {
    return <div className="status-active">Active</div>;
  }

  return <div className="status-inactive">Inactive</div>;
};

// Also acceptable — ternary for simple cases
export const UserStatus = ({ isActive }: { isActive: boolean }) => {
  return (
    <div className={isActive ? 'status-active' : 'status-inactive'}>
      {isActive ? 'Active' : 'Inactive'}
    </div>
  );
};
```

## Hooks Patterns

### Custom Hooks

```tsx
// ✅ Correct — typed hook with clear return
interface UseAuthReturn {
  user: User | null;
  loading: boolean;
  login: (email: string, password: string) => Promise<void>;
  logout: () => void;
}

export const useAuth = (): UseAuthReturn => {
  const [user, setUser] = useState<User | null>(null);
  const [loading, setLoading] = useState<boolean>(false);

  const login = async (email: string, password: string) => {
    setLoading(true);
    try {
      const response = await api.login(email, password);
      setUser(response.data);
    } finally {
      setLoading(false);
    }
  };

  const logout = () => {
    setUser(null);
  };

  return { user, loading, login, logout };
};
```

### useEffect Dependencies

```tsx
// ✅ Correct — explicit dependencies
useEffect(() => {
  fetchUser(userId);
}, [userId]);

// ❌ Wrong — missing dependencies
useEffect(() => {
  fetchUser(userId);
}, []);

// ❌ Wrong — empty deps when not needed
useEffect(() => {
  console.log('Component mounted');
}, []); // Should be removed if only logging
```

### useMemo & useCallback

```tsx
// ✅ Correct — memoize expensive computations
const sortedItems = useMemo(() => {
  return items.sort((a, b) => a.name.localeCompare(b.name));
}, [items]);

// ✅ Correct — memoize callbacks passed to children
const handleClick = useCallback(() => {
  console.log('Clicked');
}, []);

// ❌ Wrong — unnecessary memoization
const name = useMemo(() => user.name, [user]); // Too simple
```

## State Management

### Local State (useState)

```tsx
// ✅ Correct — for component-local state
export const Counter = () => {
  const [count, setCount] = useState<number>(0);

  return (
    <div>
      <p>Count: {count}</p>
      <button onClick={() => setCount(count + 1)}>Increment</button>
    </div>
  );
};
```

### Context API

```tsx
// ✅ Correct — for shared state across components
interface AuthContextType {
  user: User | null;
  login: (email: string, password: string) => Promise<void>;
  logout: () => void;
}

const AuthContext = createContext<AuthContextType | undefined>(undefined);

export const AuthProvider = ({ children }: { children: React.ReactNode }) => {
  const [user, setUser] = useState<User | null>(null);

  const login = async (email: string, password: string) => {
    const response = await api.login(email, password);
    setUser(response.data);
  };

  const logout = () => {
    setUser(null);
  };

  return (
    <AuthContext.Provider value={{ user, login, logout }}>
      {children}
    </AuthContext.Provider>
  );
};

export const useAuth = () => {
  const context = useContext(AuthContext);
  if (!context) {
    throw new Error('useAuth must be used within AuthProvider');
  }
  return context;
};
```

### Zustand (Recommended for Complex State)

```tsx
import { create } from 'zustand';

interface WarehouseState {
  warehouses: Warehouse[];
  loading: boolean;
  fetchWarehouses: () => Promise<void>;
  addWarehouse: (warehouse: Warehouse) => void;
}

export const useWarehouseStore = create<WarehouseState>((set) => ({
  warehouses: [],
  loading: false,
  fetchWarehouses: async () => {
    set({ loading: true });
    const response = await api.getWarehouses();
    set({ warehouses: response.data, loading: false });
  },
  addWarehouse: (warehouse) => 
    set((state) => ({ warehouses: [...state.warehouses, warehouse] })),
}));
```

## API Integration

### Fetch Wrapper

```tsx
// services/api.ts
interface ApiError {
  message: string;
  status: number;
}

class ApiClient {
  private baseURL: string;

  constructor(baseURL: string) {
    this.baseURL = baseURL;
  }

  async request<T>(
    endpoint: string,
    options?: RequestInit
  ): Promise<T> {
    const response = await fetch(`${this.baseURL}${endpoint}`, {
      ...options,
      headers: {
        'Content-Type': 'application/json',
        ...options?.headers,
      },
    });

    if (!response.ok) {
      const error: ApiError = {
        message: await response.text(),
        status: response.status,
      };
      throw error;
    }

    return response.json();
  }

  get<T>(endpoint: string): Promise<T> {
    return this.request<T>(endpoint);
  }

  post<T>(endpoint: string, data: unknown): Promise<T> {
    return this.request<T>(endpoint, {
      method: 'POST',
      body: JSON.stringify(data),
    });
  }
}

export const api = new ApiClient(import.meta.env.VITE_API_URL);
```

### React Query (Recommended)

```tsx
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';

// Fetch hook
export const useWarehouses = () => {
  return useQuery({
    queryKey: ['warehouses'],
    queryFn: () => api.get<Warehouse[]>('/warehouses'),
  });
};

// Mutation hook
export const useCreateWarehouse = () => {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: (data: CreateWarehouseInput) => 
      api.post<Warehouse>('/warehouses', data),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['warehouses'] });
    },
  });
};

// Usage in component
export const WarehouseList = () => {
  const { data: warehouses, isLoading, error } = useWarehouses();
  const createWarehouse = useCreateWarehouse();

  if (isLoading) return <div>Loading...</div>;
  if (error) return <div>Error: {error.message}</div>;

  return (
    <div>
      {warehouses?.map((warehouse) => (
        <div key={warehouse.id}>{warehouse.name}</div>
      ))}
    </div>
  );
};
```

## Form Handling

### React Hook Form (Recommended)

```tsx
import { useForm } from 'react-hook-form';
import { zodResolver } from '@hookform/resolvers/zod';
import { z } from 'zod';

// Validation schema
const warehouseSchema = z.object({
  name: z.string().min(3, 'Name must be at least 3 characters'),
  address: z.string().min(5, 'Address is required'),
  phone: z.string().regex(/^\+?[1-9]\d{1,14}$/, 'Invalid phone number'),
});

type WarehouseFormData = z.infer<typeof warehouseSchema>;

export const WarehouseForm = () => {
  const {
    register,
    handleSubmit,
    formState: { errors, isSubmitting },
  } = useForm<WarehouseFormData>({
    resolver: zodResolver(warehouseSchema),
  });

  const onSubmit = async (data: WarehouseFormData) => {
    await api.post('/warehouses', data);
  };

  return (
    <form onSubmit={handleSubmit(onSubmit)}>
      <div>
        <label>Name</label>
        <input {...register('name')} />
        {errors.name && <span>{errors.name.message}</span>}
      </div>

      <div>
        <label>Address</label>
        <input {...register('address')} />
        {errors.address && <span>{errors.address.message}</span>}
      </div>

      <div>
        <label>Phone</label>
        <input {...register('phone')} />
        {errors.phone && <span>{errors.phone.message}</span>}
      </div>

      <button type="submit" disabled={isSubmitting}>
        {isSubmitting ? 'Submitting...' : 'Submit'}
      </button>
    </form>
  );
};
```

## Styling

### CSS Modules (Recommended)

```tsx
// Button.module.css
.button {
  padding: 0.5rem 1rem;
  border-radius: 0.25rem;
  border: none;
  cursor: pointer;
}

.primary {
  background-color: #007bff;
  color: white;
}

.secondary {
  background-color: #6c757d;
  color: white;
}

// Button.tsx
import styles from './Button.module.css';

interface ButtonProps {
  variant?: 'primary' | 'secondary';
  children: React.ReactNode;
}

export const Button = ({ variant = 'primary', children }: ButtonProps) => {
  return (
    <button className={`${styles.button} ${styles[variant]}`}>
      {children}
    </button>
  );
};
```

### Tailwind CSS (Alternative)

```tsx
interface ButtonProps {
  variant?: 'primary' | 'secondary';
  children: React.ReactNode;
}

export const Button = ({ variant = 'primary', children }: ButtonProps) => {
  const baseClasses = 'px-4 py-2 rounded font-medium';
  const variantClasses = {
    primary: 'bg-blue-600 text-white hover:bg-blue-700',
    secondary: 'bg-gray-600 text-white hover:bg-gray-700',
  };

  return (
    <button className={`${baseClasses} ${variantClasses[variant]}`}>
      {children}
    </button>
  );
};
```

## Performance Optimization

### Code Splitting

```tsx
import { lazy, Suspense } from 'react';

// Lazy load components
const WarehouseList = lazy(() => import('./features/warehouse/WarehouseList'));
const UserProfile = lazy(() => import('./features/user/UserProfile'));

export const App = () => {
  return (
    <Suspense fallback={<div>Loading...</div>}>
      <Routes>
        <Route path="/warehouses" element={<WarehouseList />} />
        <Route path="/profile" element={<UserProfile />} />
      </Routes>
    </Suspense>
  );
};
```

### Memoization

```tsx
import { memo } from 'react';

// Memoize expensive components
export const ExpensiveComponent = memo(({ data }: { data: Data }) => {
  // Expensive rendering logic
  return <div>{/* ... */}</div>;
});

// Custom comparison function
export const UserCard = memo(
  ({ user }: { user: User }) => {
    return <div>{user.name}</div>;
  },
  (prevProps, nextProps) => prevProps.user.id === nextProps.user.id
);
```

## Testing

### Component Tests (Vitest + Testing Library)

```tsx
import { render, screen, fireEvent } from '@testing-library/react';
import { describe, it, expect, vi } from 'vitest';
import { Button } from './Button';

describe('Button', () => {
  it('renders children correctly', () => {
    render(<Button>Click me</Button>);
    expect(screen.getByText('Click me')).toBeInTheDocument();
  });

  it('calls onClick when clicked', () => {
    const handleClick = vi.fn();
    render(<Button onClick={handleClick}>Click me</Button>);
    
    fireEvent.click(screen.getByText('Click me'));
    expect(handleClick).toHaveBeenCalledTimes(1);
  });

  it('applies correct variant class', () => {
    render(<Button variant="secondary">Click me</Button>);
    const button = screen.getByText('Click me');
    expect(button).toHaveClass('btn-secondary');
  });
});
```

## Best Practices

### 1. Avoid `any` Type

```tsx
// ❌ Wrong
const handleData = (data: any) => { ... }

// ✅ Correct
const handleData = (data: User) => { ... }
// Or for unknown data
const handleData = (data: unknown) => { ... }
```

### 2. Use Strict TypeScript Config

```json
// tsconfig.json
{
  "compilerOptions": {
    "strict": true,
    "noImplicitAny": true,
    "strictNullChecks": true,
    "strictFunctionTypes": true,
    "noUnusedLocals": true,
    "noUnusedParameters": true
  }
}
```

### 3. Destructure Props

```tsx
// ✅ Correct
export const UserCard = ({ name, email }: UserCardProps) => { ... }

// ❌ Wrong
export const UserCard = (props: UserCardProps) => {
  return <div>{props.name}</div>;
}
```

### 4. Use Named Exports

```tsx
// ✅ Correct
export const Button = () => { ... }

// ❌ Wrong
export default Button;
```

### 5. Keep Components Small

```tsx
// ✅ Correct — small, focused components
export const UserCard = ({ user }: { user: User }) => {
  return (
    <div className="user-card">
      <UserAvatar user={user} />
      <UserInfo user={user} />
      <UserActions user={user} />
    </div>
  );
};

// ❌ Wrong — too much in one component
export const UserCard = ({ user }: { user: User }) => {
  return (
    <div className="user-card">
      {/* 100+ lines of JSX */}
    </div>
  );
};
```

### 6. Use Environment Variables

```tsx
// ✅ Correct
const API_URL = import.meta.env.VITE_API_URL;

// ❌ Wrong — hardcoded
const API_URL = 'https://api.example.com';
```

### 7. Handle Loading & Error States

```tsx
// ✅ Correct
export const UserList = () => {
  const { data, isLoading, error } = useUsers();

  if (isLoading) return <Spinner />;
  if (error) return <ErrorMessage error={error} />;
  if (!data) return <EmptyState />;

  return <div>{/* render data */}</div>;
};
```

## Checklist for New Components

- [ ] TypeScript types defined for all props
- [ ] Named export (not default)
- [ ] Props destructured in function signature
- [ ] Event handlers have explicit types
- [ ] Loading and error states handled
- [ ] Component is memoized if expensive
- [ ] Tests written for key functionality
- [ ] Accessibility attributes added (aria-*, role)
- [ ] No `any` types used
- [ ] Component is small and focused (<200 lines)
