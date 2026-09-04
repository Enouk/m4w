defmodule M4wWeb.Ops.ReplayController do
  use M4wWeb, :controller

  alias M4w.Ops
  alias M4wWeb.Ops.MailJSON

  def batch(conn, _params) do
    conn
    |> put_view(json: MailJSON)
    |> render(:index, mails: Ops.list_replay_batch(conn.assigns.space))
  end

  def run(conn, %{"mailIds" => mail_ids}) do
    results = Ops.run_replay(conn.assigns.space, mail_ids)
    conn |> put_view(json: MailJSON) |> render(:replay_results, results: results)
  end
end
