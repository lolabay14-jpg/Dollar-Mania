"use client";

import { useActionState } from "react";
import { useFormStatus } from "react-dom";
import {
  adjustCreditsAction,
  changePasswordAction,
  createPlayerAction,
  createStaffAction,
  loginAction,
  requestCreditsAction,
  staffRequestAction,
  type ActionState,
} from "@/server/actions";

function Submit({ children, pendingLabel }: { children: string; pendingLabel: string }) {
  const { pending } = useFormStatus();
  return (
    <button className="btn" type="submit" disabled={pending}>
      {pending ? pendingLabel : children}
    </button>
  );
}

function FormError({ state }: { state: ActionState }) {
  if (!state?.error) {
    return null;
  }
  return <p className="rounded-xl border border-bad/40 bg-bad/10 px-3 py-2 text-sm text-bad">{state.error}</p>;
}

export function LoginForm() {
  const [state, action] = useActionState(loginAction, null);
  return (
    <form action={action} className="grid gap-3">
      <FormError state={state} />
      <label className="grid gap-1 text-sm">
        Username or email
        <input className="field" name="username" autoComplete="username" required />
      </label>
      <label className="grid gap-1 text-sm">
        Password
        <input className="field" name="password" type="password" autoComplete="current-password" required />
      </label>
      <Submit pendingLabel="Signing in…">Sign in</Submit>
    </form>
  );
}

export function PasswordForm() {
  const [state, action] = useActionState(changePasswordAction, null);
  return (
    <form action={action} className="grid max-w-md gap-3">
      <FormError state={state} />
      <label className="grid gap-1 text-sm">
        Current password
        <input className="field" name="currentPassword" type="password" required />
      </label>
      <label className="grid gap-1 text-sm">
        New password
        <input className="field" name="newPassword" type="password" minLength={4} required />
      </label>
      <label className="grid gap-1 text-sm">
        Confirm new password
        <input className="field" name="confirmPassword" type="password" minLength={4} required />
      </label>
      <Submit pendingLabel="Updating…">Update password</Submit>
    </form>
  );
}

export function CreditRequestForm() {
  const [state, action] = useActionState(requestCreditsAction, null);
  return (
    <form action={action} className="grid gap-3">
      <FormError state={state} />
      <label className="grid gap-1 text-sm">
        Amount
        <input className="field" name="amount" type="number" min={1} max={100000} step={1} required />
      </label>
      <label className="grid gap-1 text-sm">
        Note
        <input className="field" name="note" maxLength={200} />
      </label>
      <Submit pendingLabel="Sending…">Request credits</Submit>
    </form>
  );
}

export function StaffCreditForm() {
  const [state, action] = useActionState(staffRequestAction, null);
  return (
    <form action={action} className="grid gap-3">
      <FormError state={state} />
      <label className="grid gap-1 text-sm">
        Amount
        <input className="field" name="amount" type="number" min={1} max={1000000} step={1} required />
      </label>
      <label className="grid gap-1 text-sm">
        Note
        <input className="field" name="note" maxLength={200} />
      </label>
      <Submit pendingLabel="Sending…">Ask the treasury</Submit>
    </form>
  );
}

export function CreatePlayerForm() {
  const [state, action] = useActionState(createPlayerAction, null);
  return (
    <form action={action} className="grid gap-3">
      <FormError state={state} />
      <label className="grid gap-1 text-sm">
        Username
        <input className="field" name="username" minLength={3} maxLength={32} required />
      </label>
      <label className="grid gap-1 text-sm">
        Email
        <input className="field" name="email" type="email" required />
      </label>
      <label className="grid gap-1 text-sm">
        Display name
        <input className="field" name="displayName" maxLength={60} />
      </label>
      <label className="grid gap-1 text-sm">
        Starting credits
        <input className="field" name="startingCredits" type="number" min={0} max={1000000} defaultValue={500} required />
      </label>
      <label className="grid gap-1 text-sm">
        Password
        <input className="field" name="password" type="password" minLength={4} required />
      </label>
      <label className="grid gap-1 text-sm">
        Confirm password
        <input className="field" name="confirmPassword" type="password" minLength={4} required />
      </label>
      <Submit pendingLabel="Creating…">Create player</Submit>
    </form>
  );
}

export function AdjustCreditsForm({ userId }: { userId: string }) {
  const [state, action] = useActionState(adjustCreditsAction, null);
  return (
    <form action={action} className="grid gap-3">
      <FormError state={state} />
      <input type="hidden" name="id" value={userId} />
      <label className="grid gap-1 text-sm">
        Amount
        <input className="field" name="amount" type="number" min={1} max={1000000} step={1} required />
      </label>
      <label className="grid gap-1 text-sm">
        Action
        <select className="field" name="action" defaultValue="add">
          <option value="add">Add credits</option>
          <option value="remove">Remove credits</option>
        </select>
      </label>
      <label className="grid gap-1 text-sm">
        Note
        <input className="field" name="note" maxLength={200} />
      </label>
      <Submit pendingLabel="Moving credits…">Move credits</Submit>
    </form>
  );
}

export function CreateStaffForm() {
  const [state, action] = useActionState(createStaffAction, null);
  return (
    <form action={action} className="grid gap-3">
      <FormError state={state} />
      <label className="grid gap-1 text-sm">
        Username
        <input className="field" name="username" minLength={3} maxLength={32} required />
      </label>
      <label className="grid gap-1 text-sm">
        Email
        <input className="field" name="email" type="email" required />
      </label>
      <label className="grid gap-1 text-sm">
        Display name
        <input className="field" name="displayName" maxLength={60} />
      </label>
      <label className="grid gap-1 text-sm">
        Password
        <input className="field" name="password" type="password" minLength={4} required />
      </label>
      <label className="grid gap-1 text-sm">
        Confirm password
        <input className="field" name="confirmPassword" type="password" minLength={4} required />
      </label>
      <Submit pendingLabel="Creating…">Create admin</Submit>
    </form>
  );
}
