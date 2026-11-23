defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsAirship.TheoCherno do
  @moduledoc """
  Handles Theo Cherno’s conversation during the airship ticket quest.

  ## Behavior

  - Introduces the Cherno household and responds to quest progress.

  ## Credits

  - Original from rAthena, authors and contributors:
    - Samuray22
    - SinSloth
    - L0ne_W0lf
    - brianluau
    - Joseph
    - Euphy
    - Capuche

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{map: "ein_in01", x: 123, y: 94, dir: 1, sprite: 851, name: "Theo Cherno", scope: :shared}
    ]

  alias Aesir.ZoneServer.Content.Npc.Functions.FCherno

  @impl true
  def on_talk(ctx) do
    progress = get_char_var(ctx, :kain_ticket, 0)

    ctx =
      cond do
        progress == 7 ->
          {ctx, _} = FCherno.call(ctx, [])
          set_char_var(ctx, :kain_ticket, 8)

        progress > 7 and progress < 10 ->
          ctx
          |> mes("[Theo Cherno]")
          |> mes("You're very kind,")
          |> mes("adventurer. There")
          |> mes("should be more people")
          |> mes("in the world like you.")

        progress > 9 and progress < 13 ->
          ctx
          |> mes("[Theo Cherno]")
          |> mes("Are you sure")
          |> mes("that you can find")
          |> mes("Tarsha's father? Oh,")
          |> mes("you must be a godsend!")

        progress > 12 ->
          ctx
          |> emotion(:smile)
          |> mes("[Theo Cherno]")
          |> mes("I'm so happy")
          |> mes("for my wife. I....")
          |> mes("I don't know how")
          |> mes("I can thank you...")

        true ->
          ctx
          |> mes("[Theo Cherno]")
          |> mes("Hmm...")
          |> mes("Can we talk later?")
          |> mes("I'm pretty busy trying")
          |> mes("to fix this thing at")
          |> mes("the moment.")
      end

    close(ctx)
  end
end
