defmodule M4w.Repo.Migrations.WidenOpsRoomsSubgoalAndKeyToText do
  use Ecto.Migration

  @moduledoc """
  `subgoal`/`key` are LLM-drafted free text (see `M4w.Ops.RoomBlueprintSchema`
  — neither field has a `maxLength`) but the original migration typed them
  `:string` (varchar(255)), so `Ops.create_room/2` 500s with
  `string_data_right_truncation` as soon as a draft's prose crosses that
  limit. Widen to `:text`, matching that both fields carry unbounded prose
  rather than bounded labels.
  """

  def change do
    alter table(:ops_rooms) do
      modify :subgoal, :text, from: :string
      modify :key, :text, from: :string
    end
  end
end
