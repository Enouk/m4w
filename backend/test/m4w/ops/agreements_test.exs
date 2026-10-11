defmodule M4w.Ops.AgreementsTest do
  use M4w.DataCase, async: true

  alias M4w.Ops
  alias M4w.Ops.{AgreementRevision, Space}
  alias M4w.Repo

  defp space!(name) do
    %Space{}
    |> Space.changeset(%{name: name, address: "#{System.unique_integer([:positive])}@m4w.test"})
    |> Repo.insert!()
  end

  defp revision!(space, attrs) do
    %AgreementRevision{}
    |> AgreementRevision.changeset(
      Map.merge(
        %{space_id: space.id, version: "v1", title: "Avtal", effective_at: ~U[2025-01-01 00:00:00Z]},
        attrs
      )
    )
    |> Repo.insert!()
  end

  test "list_agreement_revisions is scoped to the space, newest first" do
    a = space!("A")
    b = space!("B")
    old = revision!(a, %{version: "v1"})
    new = revision!(a, %{version: "v2", effective_at: ~U[2026-01-01 00:00:00Z]})
    revision!(b, %{version: "v9"})

    assert [first, second] = Ops.list_agreement_revisions(a)
    assert {first.id, second.id} == {new.id, old.id}
  end

  test "owners are stored with each revision" do
    s = space!("A")
    rev = revision!(s, %{owners: [%{"name" => "Karin", "shares" => 60}]})
    assert [%{owners: [%{"name" => "Karin", "shares" => 60}]}] = Ops.list_agreement_revisions(s)
    assert rev.id
  end
end
