defmodule M4w.Ops.FinanceTest do
  use M4w.DataCase, async: true

  alias M4w.Ops
  alias M4w.Ops.{FinanceEntry, Space}
  alias M4w.Repo

  defp space!(name) do
    %Space{}
    |> Space.changeset(%{name: name, address: "#{System.unique_integer([:positive])}@m4w.test"})
    |> Repo.insert!()
  end

  defp entry!(space, attrs) do
    %FinanceEntry{}
    |> FinanceEntry.changeset(
      Map.merge(%{space_id: space.id, title: "Post", amount: 1000}, attrs)
    )
    |> Repo.insert!()
  end

  test "list_finance_entries is scoped to the space" do
    a = space!("A")
    b = space!("B")
    mine = entry!(a, %{title: "Min"})
    entry!(b, %{title: "Annans"})

    assert [%{id: id}] = Ops.list_finance_entries(a)
    assert id == mine.id
  end

  test "list_finance_entries preloads the attached document" do
    space = space!("A")

    artifact =
      Repo.insert!(%M4w.Ops.Artifact{
        space_id: space.id,
        title: "Balansräkning",
        kind: "PDF",
        status: "signerad",
        occurred_at: DateTime.utc_now() |> DateTime.truncate(:second)
      })

    entry!(space, %{kind: "balansrakning", artifact_id: artifact.id})
    assert [%{artifact: %{id: id}}] = Ops.list_finance_entries(space)
    assert id == artifact.id
  end

  test "changeset rejects unknown kind and status" do
    space = space!("A")

    cs =
      FinanceEntry.changeset(%FinanceEntry{}, %{
        space_id: space.id,
        title: "x",
        amount: 1,
        kind: "?",
        status: "?"
      })

    assert %{kind: [_], status: [_]} = errors_on(cs)
  end
end
