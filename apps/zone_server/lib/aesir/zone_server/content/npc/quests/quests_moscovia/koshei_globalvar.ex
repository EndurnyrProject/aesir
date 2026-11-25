defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsMoscovia.KosheiGlobalvar do
  @moduledoc """
  A password-protected GM helper that shows and sets the Koshei quest's server variable.

  ## Behavior

  - After the password, shows whether `$@rus_req02` is 0 or 1 and lets the GM set it, which
    disables or enables Koshei.

  ## Credits

  - Original from rAthena, authors and Contributors
    - Kisuka
    - brianluau
    - Gepard
    - L0ne_W0lf
    - Joseph
    - Euphy
    - Lemongrass
    - Capuche

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "mosk_dun01",
        x: 3,
        y: 3,
        dir: 3,
        sprite: 958,
        name: "Koshei GlobalVar",
        scope: :shared,
        unique_name: "Koshei GlobalVar#admin"
      }
    ]

  alias Aesir.ZoneServer.Content.Npc.Functions.FGmNpc

  @impl true
  def on_talk(ctx) do
    {ctx, _} = FGmNpc.call(ctx, [])

    {ctx, password} =
      ctx
      |> mes("[Koshei GlobalVar]")
      |> mes("Please enter the password")
      |> FGmNpc.call(["orchid", 1])

    ctx = ctx |> set_local(:i, password) |> next()

    if get_local(ctx, :i, 0) == 0 do
      ctx |> mes("[Koshei GlobalVar]") |> mes("Please input the password exactly.") |> close()
    else
      ctx
      |> mes("[Koshei GlobalVar]")
      |> mes("I can tell you what the")
      |> mes("Koshei GlobalVar")
      |> mes("$@rus_req02")
      |> mes("on mosk_dun01")
      |> mes("is currently set to.")
      |> next()
      |> show_value()
    end
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  defp show_value(ctx) do
    case get_server_temp_var(ctx, "rus_req02", 0) do
      value when value in [0, 1] ->
        ctx
        |> mes("[Koshei GlobalVar]")
        |> mes("Currently the GlobalVar $@rus_req02 is set to #{value}")
        |> next()
        |> set_value()

      _ ->
        ctx |> mes("[Koshei GlobalVar]") |> mes("error") |> close()
    end
  end

  defp set_value(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Koshei GlobalVar]")
      |> mes("What would you like to set the GlobalVar to?")
      |> next()
      |> select(["0", "1", "Cancel"])

    case choice do
      1 -> set_and_notify(ctx, 0, "Koshei#rus47::OnDisable")
      2 -> set_and_notify(ctx, 1, "Koshei#rus47::OnEnable")
      3 -> close(ctx)
      _ -> ctx
    end
  end

  defp set_and_notify(ctx, value, event) do
    ctx
    |> mes("[Koshei GlobalVar]")
    |> mes("GlobalVar $@rus_req02 will now be set to '#{value}'")
    |> set_server_temp_var("rus_req02", value)
    |> donpcevent(event)
    |> close()
  end
end
