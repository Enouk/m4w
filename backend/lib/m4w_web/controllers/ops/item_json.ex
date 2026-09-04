defmodule M4wWeb.Ops.ItemJSON do
  alias M4w.Ops
  alias M4w.Ops.Item
  alias M4wWeb.Ops.{MailJSON, PassageJSON}

  def index(%{items: items}), do: %{data: Enum.map(items, &data/1)}
  def show(%{item: item}), do: %{data: data(item)}

  def detail(%{item: %Item{} = item}) do
    item = item |> M4w.Repo.preload([:room, :source_mail])
    passages = Ops.item_passages(item)

    %{
      data:
        data(item)
        |> Map.put(:sourceMail, item.source_mail && MailJSON.data(item.source_mail))
        |> Map.put(:passages, Enum.map(passages, &PassageJSON.data/1))
    }
  end

  def data(%Item{} = item) do
    %{
      id: to_string(item.id),
      roomId: to_string(item.room_id),
      title: item.title,
      meta: item.meta,
      state: item.state,
      sourceMailId: item.source_mail_id && to_string(item.source_mail_id)
    }
  end
end
