defmodule Aesir.ZoneServer.Content.Npc.Jobs.M22.Rogue.Warp do
  @moduledoc """
  Guards the door to Aragham Jr.'s hideout with a spoken password.

  ## Behavior

  - Has the player assemble the password one word at a time from menus.
  - Lets the player into the hideout only when every word is right; otherwise sends them away.

  ## Credits

  - Original from rAthena, authors and Contributors
    - kobra_k88
    - L0ne_W0lf
    - Samuray22
    - Brainstorm
    - Kisuka

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "cmd_fild09",
        x: 106,
        y: 195,
        dir: 0,
        sprite: 45,
        name: "Warp",
        scope: :shared,
        unique_name: "Warp#1",
        trigger: {1, 1}
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @password_words [
    {["My father", "Aragham", "Aragon", "Legolas"], 2},
    {["did not", "didn't", "never", "ever"], 3},
    {["hoard", "hoarded", "hide", "took", "take"], 2},
    {["upgrade items.", "forging items.", "refining item.", "upgrade item."], 1}
  ]

  @impl true
  @spec on_event(String.t(), Ctx.t()) :: Ctx.t()
  def on_event("OnTouch", ctx) do
    ctx =
      ctx
      |> mes("[???]")
      |> mes("Who's there?!")
      |> mes("Who would dare")
      |> mes("intrude my territory?")
      |> next()

    {ctx, score} =
      @password_words
      |> Enum.with_index()
      |> Enum.reduce({ctx, 0}, fn {word, index}, {ctx, score} ->
        say_word(ctx, score, word, index == 0)
      end)

    ctx = next(ctx)

    if score > 30 do
      ctx
      |> mes("^3355FF*Creeeeak*")
      |> mes("The door slowly opens.^000000")
      |> close()
      |> warp("in_rogue", 246, 25)
    else
      ctx
      |> mes("[???]")
      |> mes("What the...?")
      |> mes("Get lost!")
      |> close()
    end
  end

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx), do: ctx

  defp say_word(ctx, score, {options, answer}, first_word?) do
    {ctx, choice} = select(ctx, options)

    if choice in 1..length(options) do
      ctx = if first_word?, do: mes(ctx, "[#{char_name(ctx, 0)}]"), else: ctx
      points = if choice == answer, do: 10, else: 0
      {mes(ctx, Enum.at(options, choice - 1)), score + points}
    else
      {ctx, score}
    end
  end
end
