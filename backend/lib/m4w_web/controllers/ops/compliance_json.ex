defmodule M4wWeb.Ops.ComplianceJSON do
  alias M4w.Ops.ComplianceCheck

  def index(%{checks: checks}), do: %{data: Enum.map(checks, &data/1)}

  def data(%ComplianceCheck{} = check) do
    %{
      id: to_string(check.id),
      spaceId: to_string(check.space_id),
      title: check.title,
      ref: check.ref,
      status: check.status,
      desc: check.description,
      state: check.state
    }
  end
end
