defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsRachel.PopeSOfficeGuard do
  @moduledoc """
  A guard controls access to the pope’s office.

  ## Behavior

  - Accepts Glacial Hearts from eligible visitors and advises others about access.

  ## Credits

  - Original from rAthena, authors and Contributors
    - L0ne_W0lf
    - Euphy

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "ra_temin",
        x: 134,
        y: 128,
        dir: 3,
        sprite: 926,
        name: "Pope's Office Guard",
        scope: :shared,
        unique_name: "raofficeguard",
        hidden_name: "rac"
      },
      %{
        map: "ra_temin",
        x: 134,
        y: 134,
        dir: 3,
        sprite: 926,
        name: "Pope's Office Guard",
        scope: :shared,
        unique_name: "Pope's Office Guard#2ra"
      }
    ]

  alias Aesir.ZoneServer.Script.Rathena

  @impl true
  def on_talk(ctx) do
    cond do
      get_char_var(ctx, :ra_tem_q, 0) == 15 and count_item(ctx, 7561) > 39 ->
        ctx
        |> mes("[Pope's Office Guard]")
        |> mes("Hm? What's that you have")
        |> mes("there? Oh, you've gathered")
        |> mes("40 Glacial Hearts and brought")
        |> mes("a recommendation letter from")
        |> mes("a High Priest? Most impressive.")
        |> next()
        |> mes("[Pope's Office Guard]")
        |> mes("I think I know why you're")
        |> mes("here. Thanks for bringing")
        |> mes("those to me, and I'll let you")
        |> mes("enter and see the pope")
        |> mes(Rathena.concat(Rathena.concat("Welcome, brave ", char_name(ctx, 0)), "."))
        |> close2()
        |> set_char_var(:ra_tem_q, 16)
        |> delitem(7561, 40)

      get_char_var(ctx, :ra_tem_q, 0) == 16 ->
        ctx
        |> mes("[Pope's Office Guard]")
        |> mes("The pope is inside")
        |> mes("expecting you, so please")
        |> mes("don't keep her waiting long.")
        |> close()

      Rathena.truthy?(:erlang.band(get_char_var(ctx, :MISC_QUEST, 0), 8192)) and
          get_char_var(ctx, :aru_em, 0) in [15, 21] ->
        ctx
        |> mes("- Niren told me to pay a visit to the Pope in her office... -")
        |> close()

      Rathena.truthy?(:erlang.band(get_char_var(ctx, :MISC_QUEST, 0), 8192)) ->
        ctx
        |> mes("[Pope's Office Guard]")
        |> mes("I'm sorry, but outsiders")
        |> mes("typically aren't allowed")
        |> mes("to visit the pope without")
        |> mes("special authorization.")
        |> close()

      true ->
        ctx
        |> mes("[Pope's Office Guard]")
        |> mes("I'm sorry, but the pope")
        |> mes("is officiating a service")
        |> mes("now. Please come back")
        |> mes("after the service is ended.")
        |> close()
    end
  catch
    :throw, {:script_end, ctx} -> ctx
  end
end
