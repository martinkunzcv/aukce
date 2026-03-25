function parseBooleanEnv(value: string | undefined, defaultValue: boolean) {
  if (value === undefined) return defaultValue;
  return value === "true";
}

export const featureFlags = {
  disableCredentialsAuth: parseBooleanEnv(
    process.env.AUTH_DISABLE_CREDENTIALS,
    false,
  ),
  disablePublicRegistration: parseBooleanEnv(
    process.env.AUTH_DISABLE_PUBLIC_REGISTRATION,
    false,
  ),
} as const;
