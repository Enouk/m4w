defmodule M4w.Repo.Migrations.WidenOpsMailsFromAndReplayKey do
  use Ecto.Migration

  @moduledoc """
  Follow-up to `WidenOpsMailsTextFields`: `from` is the sender's display name
  straight from the mail header, and `replay_key` is LLM-drafted free text
  (same as `ops_rooms.key`, widened in `WidenOpsRoomsSubgoalAndKeyToText`) —
  neither is bounded, so varchar(255) can make imports and replay raise
  `string_data_right_truncation`.
  """

  def change do
    alter table(:ops_mails) do
      modify :from, :text, from: :string
      modify :replay_key, :text, from: :string
    end
  end
end
