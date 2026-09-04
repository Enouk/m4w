defmodule M4wWeb.Ops.UserJSON do
  alias M4w.Ops
  alias M4w.Ops.User

  def data(%User{} = user) do
    %{
      id: to_string(user.id),
      name: user.name,
      email: user.email,
      role: user.role,
      org: Ops.user_org_name(user),
      initials: user.initials,
      spaces: Ops.user_space_ids(user) |> Enum.map(&to_string/1)
    }
  end
end
