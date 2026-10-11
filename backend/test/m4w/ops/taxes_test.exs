defmodule M4w.Ops.TaxesTest do
  use M4w.DataCase, async: true

  alias M4w.Ops
  alias M4w.Ops.{Space, TaxCheck}
  alias M4w.Repo

  defp space!(name) do
    %Space{}
    |> Space.changeset(%{name: name, address: "#{System.unique_integer([:positive])}@m4w.test"})
    |> Repo.insert!()
  end

  defp check!(space, attrs) do
    %TaxCheck{}
    |> TaxCheck.changeset(Map.merge(%{space_id: space.id, title: "Moms"}, attrs))
    |> Repo.insert!()
  end

  test "list_tax_checks is scoped to the space" do
    a = space!("A")
    b = space!("B")
    mine = check!(a, %{title: "Min"})
    check!(b, %{title: "Annans"})

    assert [%{id: id}] = Ops.list_tax_checks(a)
    assert id == mine.id
  end

  test "changeset rejects unknown kind and status" do
    space = space!("A")

    refute TaxCheck.changeset(%TaxCheck{}, %{space_id: space.id, title: "x", kind: "nope"}).valid?

    refute TaxCheck.changeset(%TaxCheck{}, %{space_id: space.id, title: "x", status: "nope"}).valid?
  end

  test "amount and meeting are optional" do
    space = space!("A")
    assert %TaxCheck{amount: nil, meeting_id: nil, status: "att_betala"} = check!(space, %{})
  end
end
