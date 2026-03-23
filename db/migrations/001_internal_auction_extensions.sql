-- Intended migration overlay for an existing WeBid schema.
-- Apply after importing the upstream WeBid database schema.

ALTER TABLE `users`
  ADD COLUMN `external_subject` varchar(191) NULL,
  ADD COLUMN `external_issuer` varchar(191) NULL,
  ADD COLUMN `display_name` varchar(191) NULL,
  ADD COLUMN `account_source` enum('local','oidc') NOT NULL DEFAULT 'oidc',
  ADD COLUMN `is_registration_disabled` tinyint(1) NOT NULL DEFAULT 1,
  ADD UNIQUE KEY `uniq_users_external_identity` (`external_issuer`, `external_subject`);

CREATE TABLE IF NOT EXISTS `user_roles` (
  `id` bigint unsigned NOT NULL AUTO_INCREMENT,
  `user_id` bigint unsigned NOT NULL,
  `role_name` varchar(64) NOT NULL,
  `granted_at` datetime NOT NULL DEFAULT current_timestamp(),
  PRIMARY KEY (`id`),
  UNIQUE KEY `uniq_user_role` (`user_id`, `role_name`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

ALTER TABLE `auctions`
  ADD COLUMN `state` enum('draft','scheduled','running','ended_pending_approval','approved','cancelled') NOT NULL DEFAULT 'draft',
  ADD COLUMN `approved_by` bigint unsigned NULL,
  ADD COLUMN `approved_at` datetime NULL,
  ADD COLUMN `approval_note` text NULL,
  ADD COLUMN `provisional_winner_user_id` bigint unsigned NULL,
  ADD KEY `idx_auctions_state` (`state`);

CREATE TABLE IF NOT EXISTS `audit_log` (
  `id` bigint unsigned NOT NULL AUTO_INCREMENT,
  `occurred_at` datetime NOT NULL DEFAULT current_timestamp(),
  `actor_user_id` bigint unsigned NULL,
  `event_type` varchar(64) NOT NULL,
  `entity_type` varchar(64) NOT NULL,
  `entity_id` bigint unsigned NULL,
  `remote_ip` varchar(64) NULL,
  `details_json` longtext NOT NULL,
  PRIMARY KEY (`id`),
  KEY `idx_audit_entity` (`entity_type`, `entity_id`),
  KEY `idx_audit_actor` (`actor_user_id`, `occurred_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

ALTER TABLE `bids`
  ADD COLUMN `visible_to_bidder` tinyint(1) NOT NULL DEFAULT 1,
  ADD KEY `idx_bids_auction_created` (`auction`, `bidwhen`);
