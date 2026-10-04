import { pool } from "../src/db";
import { ensureSuperAdmin } from "../src/services/userService";

ensureSuperAdmin()
  .then((result) => {
    console.log(result.created ? "created" : "exists");
    return pool.end();
  })
  .catch((error: unknown) => {
    console.error(error instanceof Error ? error.message : "ensure failed");
    return pool.end().finally(() => process.exit(1));
  });
