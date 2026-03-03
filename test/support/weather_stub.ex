defmodule BashStartpage.WeatherStub do
  @moduledoc "Plug that returns a static weather response for use in tests."

  def call(conn, _opts) do
    Req.Test.json(conn, %{
      "current_condition" => [
        %{"temp_C" => "20", "weatherDesc" => [%{"value" => "Sunny"}]}
      ]
    })
  end
end
