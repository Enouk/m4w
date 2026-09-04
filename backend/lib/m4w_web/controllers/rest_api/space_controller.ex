defmodule M4wWeb.RestAPI.SpaceController do
  use M4wWeb, :controller

  alias M4w.World

  @space_json M4wWeb.RestAPI.SpaceJSON

  def create(conn, %{"goal" => goal}) when is_binary(goal) do
    create_space(conn, %{"title" => goal})
  end

  def create(conn, %{"goal" => goal}) when is_map(goal) do
    create_space(conn, goal)
  end

  def create(conn, %{"title" => _title} = goal) do
    create_space(conn, goal)
  end

  def create(conn, _params) do
    conn
    |> put_status(:unprocessable_entity)
    |> put_view(json: @space_json)
    |> render(:error, errors: %{goal: ["must be a string or an object with a title"]})
  end

  defp create_space(conn, goal_params) do
    case World.create_space_from_goal(goal_params) do
      {:ok, space} ->
        conn
        |> put_status(:created)
        |> put_view(json: @space_json)
        |> render(:show, space: space)

      {:error, _operation, changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> put_view(json: @space_json)
        |> render(:error, errors: translate_errors(changeset))
    end
  end

  defp translate_errors(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {message, opts} ->
      Regex.replace(~r"%{(\w+)}", message, fn _, key ->
        opts
        |> Keyword.get(String.to_existing_atom(key), key)
        |> to_string()
      end)
    end)
  end
end
