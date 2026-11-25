defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsLouyang.FamiliarLookingPatient do
  @moduledoc """
  A sick patient reacts to the doctor quest’s progress.

  ## Behavior

  - Starts the doctor quest on the first conversation and changes dialogue with progress.

  ## Credits

  - Original from rAthena, authors and Contributors
    - Evera
    - Lupus
    - SinSloth
    - L0ne_W0lf
    - Paradox924X
    - Euphy

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "lou_in02",
        x: 272,
        y: 55,
        dir: 0,
        sprite: 798,
        name: "Familiar-Looking Patient",
        scope: :shared
      }
    ]

  @impl true
  def on_talk(ctx) do
    progress = get_char_var(ctx, :ch_par, 0)

    cond do
      progress == 0 ->
        ctx
        |> mes("[??????]")
        |> mes("Awwww.....")
        |> mes("Ummm....")
        |> mes("^666666*Cough...cough...*^000000")
        |> emotion(:huk)
        |> set_char_var(:ch_par, 1)
        |> close()

      progress < 18 ->
        ctx
        |> mes("[??????]")
        |> mes("^666666*Cough cough...*^000000")
        |> mes("Aww......www...")
        |> mes("Aww...wwww..")
        |> emotion(:think)
        |> close()

      true ->
        ctx
        |> mes("[??????]")
        |> mes("Zzzzzzz")
        |> mes("Zzzzz.....")
        |> mes("Zzzzz.....")
        |> close()
    end
  catch
    :throw, {:script_end, ctx} -> ctx
  end
end
