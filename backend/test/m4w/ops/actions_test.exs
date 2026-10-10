defmodule M4w.Ops.ActionsTest do
  use M4w.DataCase, async: true

  alias M4w.Ops
  alias M4w.Ops.{Action, Space}
  alias M4w.Repo

  defp space!(name) do
    %Space{}
    |> Space.changeset(%{name: name, address: "#{System.unique_integer([:positive])}@m4w.test"})
    |> Repo.insert!()
  end

  defp action!(space, attrs) do
    %Action{}
    |> Action.changeset(Map.merge(%{space_id: space.id, title: "Uppgift", assignee: "VD"}, attrs))
    |> Repo.insert!()
  end

  test "list_actions is scoped to the space" do
    a = space!("A")
    b = space!("B")
    mine = action!(a, %{title: "Min"})
    action!(b, %{title: "Annans"})

    assert [%{id: id}] = Ops.list_actions(a)
    assert id == mine.id
  end

  test "update_action changes status and rejects unknown statuses" do
    space = space!("A")
    action = action!(space, %{})

    assert {:ok, %{status: "klar"}} = Ops.update_action(action, %{"status" => "klar"})
    assert {:error, changeset} = Ops.update_action(action, %{"status" => "bogus"})
    assert %{status: [_]} = errors_on(changeset)
  end

  test "get_action! does not return actions from other spaces" do
    a = space!("A")
    b = space!("B")
    action = action!(b, %{})

    assert_raise Ecto.NoResultsError, fn -> Ops.get_action!(a, action.id) end
  end
end
