import { createHandler, withRegistrationRateLimit } from "@/lib/api";
import { register } from "@/lib/api/handlers/auth.handlers";
import { featureFlags } from "@/lib/config/features";
import { NotFoundError } from "@/lib/api/errors";

const registerOrBlock = async (...args: Parameters<typeof register>) => {
  if (featureFlags.disablePublicRegistration) {
    throw new NotFoundError("Not found");
  }
  return register(...args);
};

export default createHandler({
  POST: [[withRegistrationRateLimit], registerOrBlock],
});
