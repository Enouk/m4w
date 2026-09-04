defmodule M4wWeb.Ops.VerificationJSON do
  alias M4w.Ops.Verification

  def index(%{verifications: verifications}), do: %{data: Enum.map(verifications, &data/1)}

  def data(%Verification{} = verification) do
    %{
      id: to_string(verification.id),
      ver: verification.ver,
      spaceId: to_string(verification.space_id),
      date: DateTime.to_iso8601(verification.occurred_at),
      supplier: verification.supplier,
      amount: verification.amount,
      status: verification.status,
      archiveUntil: verification.archive_until,
      traceFromRoomId:
        verification.trace_from_room_id && to_string(verification.trace_from_room_id),
      traceToRoomId: verification.trace_to_room_id && to_string(verification.trace_to_room_id)
    }
  end
end
