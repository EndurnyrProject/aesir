defmodule Aesir.ZoneServer.Content.Npc.Quests.Seals.BrisingamenSeal.Gravestone do
  @moduledoc """
  A gravestone reveals an epitaph as the Brisingamen seal quest progresses.

  ## Behavior

  - Displays an ordinary gravestone, an eroded epitaph, or Lowen's epitaph according to quest progress.

  ## Credits

  - Original from rAthena, authors and Contributors
    - SinSloth
    - MasterOfMuppets
    - Toms
    - L0ne_W0lf
    - Samuray22
    - Euphy
    - Capuche

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{map: "prontera", x: 262, y: 353, dir: 0, sprite: 111, name: "Gravestone", scope: :shared}
    ]

  @impl true
  def on_talk(ctx) do
    cond do
      get_server_var(ctx, "God2", 0) <= get_server_temp_var(ctx, "god_check1", 0) ->
        ctx
        |> mes("^3355FFIt's just an")
        |> mes("ordinary gravestone.^000000")
        |> next()
        |> mes("^3355FFNothing really")
        |> mes(
          "sets it apart from the rest of the tombstones here in the Prontera cemetary.^000000"
        )
        |> close()

      get_char_var(ctx, :god_brising, 0) > 33 ->
        ctx
        |> mes("Lowen Ellenen")
        |> mes(" ")
        |> mes(" XXXX. XX. XX.")
        |> mes("Her noble spirit")
        |> mes("was sent to the holy")
        |> mes("place by Valkyrie's will.")
        |> close()

      true ->
        ctx
        |> mes(
          "^3355FFYou couldn't read the rest of the epitaph since the tombstone has been eroded with time.^000000"
        )
        |> close()
    end
  catch
    :throw, {:script_end, ctx} -> ctx
  end
end
