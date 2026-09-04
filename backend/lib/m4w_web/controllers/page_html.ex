defmodule M4wWeb.PageHTML do
  @moduledoc """
  This module contains pages rendered by PageController.

  See the `page_html` directory for all templates available.
  """
  use M4wWeb, :html

  embed_templates "page_html/*"
end
