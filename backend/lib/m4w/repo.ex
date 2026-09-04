defmodule M4w.Repo do
  use Ecto.Repo,
    otp_app: :m4w,
    adapter: Ecto.Adapters.Postgres
end
