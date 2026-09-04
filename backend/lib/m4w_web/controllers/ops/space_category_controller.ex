defmodule M4wWeb.Ops.SpaceCategoryController do
  use M4wWeb, :controller

  alias M4w.Ops

  def index(conn, _params), do: json(conn, Ops.space_categories())
end
