import { config } from "../src/config";
import { pool } from "../src/db";
import { hashPassword } from "../src/services/authService";

const GAMES = [
  {
    name: "Lucky Dollar",
    slug: "lucky-dollar",
    description: "Three reels and one payline.",
    difficulty: "EASY",
    category: "SLOTS",
    minimumBet: 1,
    maximumBet: 100,
  },
  {
    name: "Golden Fortune",
    slug: "golden-fortune",
    description: "Five reels with larger line wins.",
    difficulty: "MEDIUM",
    category: "SLOTS",
    minimumBet: 5,
    maximumBet: 500,
  },
  {
    name: "Multiplier Rush",
    slug: "dollar-rush",
    description: "Pick a lane and ride the multiplier rush.",
    difficulty: "HARD",
    category: "REACTION",
    minimumBet: 10,
    maximumBet: 1000,
  },
  {
    name: "Scratch Mania",
    slug: "scratch-mania",
    description: "Scratch a card and reveal the prize.",
    difficulty: "EASY",
    category: "SCRATCH",
    minimumBet: 2,
    maximumBet: 50,
  },
  {
    name: "Lucky Spin",
    slug: "lucky-spin",
    description: "Spin a wheel of credit prizes.",
    difficulty: "EASY",
    category: "SPIN",
    minimumBet: 5,
    maximumBet: 100,
  },
  {
    name: "Coin Flip",
    slug: "coin-flip",
    description: "Call heads or tails.",
    difficulty: "MEDIUM",
    category: "CHOICE",
    minimumBet: 10,
    maximumBet: 200,
  },
  {
    name: "Treasure Box",
    slug: "treasure-box",
    description: "Open one of four mystery boxes.",
    difficulty: "MEDIUM",
    category: "CHOICE",
    minimumBet: 5,
    maximumBet: 150,
  },
  {
    name: "Cash Match",
    slug: "cash-match",
    description: "Reveal cards and match the symbols.",
    difficulty: "MEDIUM",
    category: "MATCH",
    minimumBet: 5,
    maximumBet: 150,
  },
  {
    name: "Diamond Drop",
    slug: "diamond-drop",
    description: "Falling gems that match in a row.",
    difficulty: "HARD",
    category: "MATCH",
    minimumBet: 10,
    maximumBet: 400,
  },
  {
    name: "Bonus Burst",
    slug: "bonus-burst",
    description: "A short timed bonus round.",
    difficulty: "MEDIUM",
    category: "BONUS",
    minimumBet: 10,
    maximumBet: 250,
  },
  {
    name: "Jackpot Wheel",
    slug: "jackpot-wheel",
    description: "A larger wheel with a rare jackpot.",
    difficulty: "HARD",
    category: "SPIN",
    minimumBet: 20,
    maximumBet: 500,
  },
  {
    name: "Cards",
    slug: "higher-card",
    description: "Draw a card. Higher than the house wins.",
    difficulty: "EASY",
    category: "CARDS",
    minimumBet: 5,
    maximumBet: 200,
  },
  {
    name: "Fruit Spin",
    slug: "fruit-spin",
    description: "Spin a fruit wheel and land on a prize.",
    difficulty: "MEDIUM",
    category: "SPIN",
    minimumBet: 5,
    maximumBet: 100,
  },
  {
    name: "Lucky Wheel",
    slug: "lucky-wheel",
    description: "A prize wheel with coins, symbols, and multipliers.",
    difficulty: "MEDIUM",
    category: "SPIN",
    minimumBet: 5,
    maximumBet: 200,
  },
  {
    name: "Prize Spinner",
    slug: "prize-spinner",
    description: "A glowing spinner that settles on a reward.",
    difficulty: "MEDIUM",
    category: "SPIN",
    minimumBet: 5,
    maximumBet: 150,
  },
  {
    name: "Fish Shooter",
    slug: "fishing",
    description: "Aim an underwater cannon and shoot the fish.",
    difficulty: "MEDIUM",
    category: "FISHING",
    minimumBet: 5,
    maximumBet: 100,
  },
  {
    name: "Dice",
    slug: "dice",
    description: "Roll two dice and land a winning total.",
    difficulty: "MEDIUM",
    category: "CHOICE",
    minimumBet: 5,
    maximumBet: 100,
  },
  {
    name: "Diamond Spin",
    slug: "diamond-spin",
    description: "A crystal wheel of gems and diamonds.",
    difficulty: "MEDIUM",
    category: "SPIN",
    minimumBet: 5,
    maximumBet: 200,
  },
  {
    name: "Mystery Box",
    slug: "mystery-box",
    description: "Open one sealed chest and reveal the prize.",
    difficulty: "EASY",
    category: "CHOICE",
    minimumBet: 5,
    maximumBet: 150,
  },
  {
    name: "Target Blast",
    slug: "target-blast",
    description: "An arcade gallery. Hit the targets before they fade.",
    difficulty: "MEDIUM",
    category: "REACTION",
    minimumBet: 5,
    maximumBet: 200,
  },
  {
    name: "Aeroplane Rush",
    slug: "aeroplane-rush",
    description: "Fly the plane, dodge clouds, and collect coins.",
    difficulty: "MEDIUM",
    category: "REACTION",
    minimumBet: 5,
    maximumBet: 200,
  },
  {
    name: "Bottle Blast",
    slug: "bottle-blast",
    description: "Aim an arcade launcher and break the bottles.",
    difficulty: "MEDIUM",
    category: "REACTION",
    minimumBet: 5,
    maximumBet: 200,
  },
  {
    name: "Lucky Number",
    slug: "lucky-number",
    description: "Pick a number and see what is drawn.",
    difficulty: "MEDIUM",
    category: "MATCH",
    minimumBet: 5,
    maximumBet: 100,
  },
];

async function seed() {
  const adminHash = await hashPassword(config.DEFAULT_ADMIN_PASSWORD);
  await pool.query(
    `INSERT INTO users (username, email, password_hash, role)
     VALUES ($1, $2, $3, 'ADMIN')
     ON CONFLICT (username) DO NOTHING`,
    [config.DEFAULT_ADMIN_USERNAME, `${config.DEFAULT_ADMIN_USERNAME}@dollarmania.local`, adminHash],
  );

  await seedPlayer(config.DEFAULT_PLAYER_USERNAME, "Alex Rivera", config.DEFAULT_PLAYER_PASSWORD, config.STARTING_CREDITS);
  await seedPlayer(
    config.DEFAULT_PLAYER2_USERNAME,
    "Jordan Lee",
    config.DEFAULT_PLAYER2_PASSWORD,
    config.STARTING_CREDITS,
  );
  const { ensureSuperAdmin } = await import("../src/services/userService");
  await ensureSuperAdmin();

  for (const game of GAMES) {
    await pool.query(
      `INSERT INTO slot_games (name, slug, description, difficulty, category, minimum_bet, maximum_bet, is_active)
       VALUES ($1, $2, $3, $4, $5, $6, $7, true)
       ON CONFLICT (slug) DO UPDATE SET
         name = EXCLUDED.name,
         description = EXCLUDED.description,
         difficulty = EXCLUDED.difficulty,
         category = EXCLUDED.category,
         minimum_bet = EXCLUDED.minimum_bet,
         maximum_bet = EXCLUDED.maximum_bet,
         is_active = true`,
      [game.name, game.slug, game.description, game.difficulty, game.category, game.minimumBet, game.maximumBet],
    );
  }
  console.log("Seed finished. Development accounts are ready.");
}

async function seedPlayer(username: string, displayName: string, password: string, credits: number) {
  const existing = await pool.query<{ id: string }>("SELECT id FROM users WHERE username = $1", [username]);
  if (existing.rowCount) {
    return;
  }
  const passwordHash = await hashPassword(password);
  const client = await pool.connect();
  try {
    await client.query("BEGIN");
    const user = await client.query<{ id: string }>(
      `INSERT INTO users (username, email, password_hash, role)
       VALUES ($1, $2, $3, 'PLAYER')
       RETURNING id`,
      [username, `${username}@dollarmania.local`, passwordHash],
    );
    const userId = user.rows[0].id;
    await client.query(
      `INSERT INTO player_profiles (user_id, display_name, level, experience)
       VALUES ($1, $2, 1, 0)`,
      [userId, displayName],
    );
    await client.query("INSERT INTO wallets (user_id, balance) VALUES ($1, $2)", [userId, credits]);
    if (credits > 0) {
      await client.query(
        `INSERT INTO credit_transactions
           (user_id, amount, balance_after, transaction_type, description)
         VALUES ($1, $2, $2, 'BONUS', 'Starting balance')`,
        [userId, credits],
      );
    }
    await client.query("COMMIT");
  } catch (error) {
    await client.query("ROLLBACK");
    throw error;
  } finally {
    client.release();
  }
}

seed()
  .then(async () => {
    await pool.end();
  })
  .catch(async (error: unknown) => {
    const message = error instanceof Error ? error.message : "Seed failed.";
    console.error(message.replace(/postgres(?:ql)?:\/\/\S+/gi, "[redacted]"));
    await pool.end();
    process.exit(1);
  });
