defmodule M4wWeb.ErrorJSONTest do
  use M4wWeb.ConnCase, async: true

  test "renders 404" do
    assert M4wWeb.ErrorJSON.render("404.json", %{}) == %{errors: %{detail: "Not Found"}}
  end

  test "renders 500" do
    assert M4wWeb.ErrorJSON.render("500.json", %{}) ==
             %{errors: %{detail: "Internal Server Error"}}
  end
end
