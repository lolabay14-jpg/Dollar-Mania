export type Role = "PLAYER" | "ADMIN" | "SUPER_ADMIN";

export type GameMode = "EASY" | "MEDIUM" | "HARD";

export type ProfileLevel = "EASY" | "MEDIUM" | "HARD" | "DEFAULT";

export type PublicUser = {
  id: string;
  username: string;
  role: Role;
};

export type SessionUser = PublicUser;

export type PlayerProfile = {
  id: string;
  username: string;
  displayName: string | null;
  avatar: string | null;
  level: number;
  experience: number;
  credits: number;
  spins: number;
  wins: number;
  losses: number;
};

export type PlayerSummary = {
  id: string;
  username: string;
  email: string;
  role: Role;
  isActive: boolean;
  displayName: string | null;
  level: number | null;
  experience: number | null;
  balance: number;
  gameMode: GameMode;
  createdAt: string;
};

export type GameSummary = {
  id: string;
  name: string;
  slug: string;
  description: string;
  difficulty: string;
  category: string;
  minimumBet: number;
  maximumBet: number;
  isActive: boolean;
  enabled?: boolean;
  spins?: number;
};

export type Transaction = {
  id: string;
  userId: string;
  username: string;
  displayName: string | null;
  amount: number;
  balanceAfter: number;
  transactionType: string;
  description: string;
  createdAt: string;
};

export type SpinRecord = {
  id: string;
  gameName: string;
  gameSlug: string;
  betAmount: number;
  winAmount: number;
  multiplier: number;
  result: unknown;
  createdAt: string;
};

export type CreditRequest = {
  id: string;
  userId?: string;
  amount: number;
  status: string;
  createdAt: string;
  reviewedAt: string | null;
  note: string;
  requestNote: string;
  username?: string;
  email?: string;
  role?: string;
  balance?: number;
};

export type Activity = {
  id: string;
  action: string;
  amount: number | null;
  description: string | null;
  adminUsername: string;
  targetUsername: string | null;
  targetDisplayName: string | null;
  createdAt: string;
};

export type PlayRow = {
  id: string;
  username: string;
  gameName: string;
  betAmount: number;
  winAmount: number;
  createdAt: string;
};

export type AdminOverview = {
  totalPlayers: number;
  activePlayers: number;
  totalAdmins: number;
  activeAdmins: number;
  activeGames: number;
  totalCredits: number;
  playerCredits: number;
  allocatedCredits: number;
  myBalance: number;
  totalGames: number;
  totalSpins: number;
  totalSessions: number;
  recentTransactions: Transaction[];
  recentActivity: Activity[];
  recentPlays: PlayRow[];
  pendingPlayerRequests: number;
  pendingAdminRequests: number;
};

export type ParameterDef = {
  key: string;
  label: string;
  min: number;
  max: number;
  step: number;
  defaultValue: number;
};

export type PlayerGameProfile = {
  userId: string;
  username: string;
  email: string;
  gameId: string;
  slug: string;
  gameName: string;
  gameDifficulty: string;
  assignedProfile: ProfileLevel;
  parameters: Record<string, number>;
  parameterDefs: ParameterDef[];
  updatedAt: string | null;
};

export type PlayerGameAccessItem = {
  gameId: string;
  slug: string;
  name: string;
  description: string;
  category: string;
  difficulty: string;
  globallyActive: boolean;
  enabled: boolean;
  source: "default" | "explicit";
};

export type PlayerGameAccessSummary = {
  player: {
    id: string;
    username: string;
    email: string;
    status: string;
    credits: number;
  };
  totalGames: number;
  enabledCount: number;
  disabledCount: number;
  games: PlayerGameAccessItem[];
};

export type PlayReceipt = {
  playId: string;
  spinId: string;
  result: string[];
  grid: string[][];
  highlights: number[];
  title: string;
  betAmount: number;
  winAmount: number;
  multiplier: number;
  balance: number;
  presentation: Record<string, unknown>;
};
