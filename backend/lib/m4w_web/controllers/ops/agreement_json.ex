defmodule M4wWeb.Ops.AgreementJSON do
  alias M4w.Ops.AgreementRevision

  def index(%{revisions: revisions}), do: %{data: Enum.map(revisions, &data/1)}

  def data(%AgreementRevision{} = rev) do
    %{
      id: to_string(rev.id),
      version: rev.version,
      title: rev.title,
      summary: rev.summary,
      changedBy: rev.changed_by,
      effectiveDate: DateTime.to_iso8601(rev.effective_at),
      owners: owners(rev.owners),
      document: document(rev)
    }
  end

  defp owners(owners) do
    total = Enum.reduce(owners, 0, &(&2 + shares(&1)))

    Enum.map(owners, fn o ->
      %{
        name: o["name"],
        shares: shares(o),
        percent: if(total > 0, do: Float.round(shares(o) * 100 / total, 1), else: 0.0)
      }
    end)
  end

  defp shares(%{"shares" => n}) when is_integer(n), do: n
  defp shares(_), do: 0

  defp document(%AgreementRevision{artifact: %{} = a}) do
    %{id: to_string(a.id), title: a.title, kind: a.kind, size: a.size, url: a.url}
  end

  defp document(_), do: nil
end
