import 'dart:ui';

import 'package:flame/position.dart';
import 'package:flame/sprite.dart';
import 'package:flame/text_config.dart';
import 'package:flutter/gestures.dart';

import 'package:panda_jitsu/cards/card.dart';
import 'package:panda_jitsu/cards/deck.dart';
import 'package:panda_jitsu/card_status.dart';
import 'package:panda_jitsu/jitsu_game.dart';

/// The card container on bottom of screen.
/// 
/// This class will handle the bottom part of the screen, including where cards should be diverted and keeps track of empty mySlots as cards are selected.
class Tray {

	/// The padding factor between cards in the tray.
	/// 
	/// This padding has a default value of 1.2.
	static const double cardPadding = 1.2;

	/// The padding between the edges of the screen and the tray position (measured in tiles).
	/// 
	/// The trayPadding has a default value of 1 tile from the left edge and 6.25 tiles from the top.
	static const Offset trayPadding = Offset(1, 6.25);

	/// Number of pixels to shift per character.
	static const double pixelsPerCharacter = 11.0;

	/// The configuration of the text on screen.
	static const TextConfig config = TextConfig(
		color: Color(0xFF000000),
		fontSize: 20.0, 
		fontFamily: 'Julee'
	);


	/// The player's deck of cards.
	final Deck myDeck;

	/// The opponent's deck of cards.
	final Deck comDeck;

	/// The players number of card slots available.
	final int mySize;

	/// The opponent's number of card slots available.
	final int comSize;

	/// A reference to the JitsuGame object.
	final JitsuGame game;

	// The opponent's middle 'pot' card.
	Card comPot;

	/// The player's middle 'pot' card.
	Card myPot;

	/// Whether the opponent's pot card has been flipped.
	/// 
	/// This boolean defaults to a value of false.
	bool hasBeenFlipped = false; 

	/// A list of cards in the opponent's hand.
	List<Card> comSlots;

	/// A list of cards in the player's hand.
	List<Card> mySlots;

	/// The top left position of the tray.
	Position trayPos;

	/// The rectangular area of the tray.
  	Rect trayArea;

	/// The opponent's username.
	String comName;

	/// The player's username.
	String myName;

	/// The sprite image used as the tray background.
	/// 
	/// This asset is currently located at background/tray.png
	Sprite traySprite = Sprite('background/tray.png');
	
	/// Constructs a new Tray object.
	Tray(this.game, this.myDeck, this.mySize, this.comDeck, this.comSize) {
		comSlots = List<Card>(comSize);
		mySlots = List<Card>(mySize);
		trayPos = Position(
			game.tileSize * trayPadding.dx, // padding from left edge
			game.tileSize * trayPadding.dy // padding from top edge
		);
		trayArea = Rect.fromLTWH(
			trayPos.x,
			trayPos.y,
			game.screenSize.width - trayPos.x * 2, // equal padding left/right
			game.screenSize.height - trayPos.y // extend to bottom of screen
		);
		comName = "GRASSHOPPER";
		myName = "SENSEI";
	}

	/// Returns whether the pot is empty or not.
	bool _potIsEmpty() {
		return myPot == null && comPot == null;
	}

	/// Returns whether the cards have loaded.
	bool _slotHasLoaded(List<Card> slot) {
		return slot != null && slot.isNotEmpty;
	}

	// Returns whether both player's cards are in the middle 'pot'
	bool bothCardsReady() {
		bool myCardReady = myPot != null && myPot.isDoneMoving();
		bool comCardReady = comPot != null && comPot.isDoneMoving();
		return myCardReady && comCardReady;
	}

	/// Renders the right name to each side
	void _renderNames(Canvas c, Position right, Position left,
						  String leftName, String rightName) {
		right.x -= pixelsPerCharacter * rightName.length;
		config.render(c, leftName, left);
		config.render(c, rightName, right);
	}

	/// Renders the players names based on which side their deck is on.
	void renderNames(Deck deck, Canvas c) {
		Position left = trayPos.add(Position(25, 15));
		Position right = Position(game.screenSize.width - trayPos.x - 25, trayPos.y + 15);
		
		if (deck.alignLeft) {
			_renderNames(c, right, left, myName, comName);
		} else {
			_renderNames(c, right, left, comName, myName);
		}
		
	}

	/// Renders the given list of cards and given pot card to the canvas.
	void renderCards(List<Card> slot, Card pot, Canvas c) {
		if (_slotHasLoaded(slot)) {
			slot.forEach((Card card) => card.render(c)); // draw each card 
		}
		if (pot != null) {
			pot.render(c);
		}
	}

	/// Finds and returns the coordinate of the deck at the given position.
	Position getSlotPositionFromIndex(int i, Deck deck) {
		double fromLeftEdge = 30 + trayPos.x + (cardPadding * deck.cardSize.width * i);
		double fromTopEdge = 40 + trayPos.y;
		if (!deck.alignLeft) {
			fromLeftEdge += deck.cardSize.width;
			fromLeftEdge = game.screenSize.width - fromLeftEdge;
		}
		return Position(fromLeftEdge, fromTopEdge);
	}

	/// Updates the given list of cards and given pot card to the canvas.
	void updateCards(List<Card> slot, int size, Deck deck, Card pot, double t) {
		if (_slotHasLoaded(slot)) { // check the the slot
			for (int i = 0; i < size; i++) { // loop through each slots
				// check all slots are filled
				if (slot.elementAt(i) == null || slot.elementAt(i).status != CardStatus.inHand) { 
					Card nextCard =	deck.draw(); // if not, draw a new card
					Position openSlot = getSlotPositionFromIndex(i, deck);
					nextCard.setTargetLocation(openSlot); // update target
					nextCard.status = CardStatus.inHand;
					slot[i] = nextCard; // fill the slot with reference to card
				}
				Card currentCard = slot.elementAt(i);
				currentCard.update(t);
			}
		}
		if (pot != null) {
			pot.update(t);
		}
	}

	/// Renders the tray (and its components) to the canvas
	void render(Canvas c) {
		traySprite.renderRect(c, trayArea); // render tray background
		renderCards(comSlots, comPot, c); // render opponents cards
		renderCards(mySlots, myPot, c); // render my cards
		renderNames(myDeck, c);
	}

	/// Updates the tray.
	/// 
	/// Loops through the five mySlots and makes sure they are all full. If not, it will draw the next card from the deck to fill the open slot.
	void update(double t) {
		updateCards(mySlots, mySize, myDeck, myPot, t);
		updateCards(comSlots, comSize, comDeck, comPot, t);
		if (bothCardsReady() && !hasBeenFlipped) {
			hasBeenFlipped = true;
			comPot.flip();
		}
	}

	/// Handles user taps.
	void handleTouchAt(Offset touchPoint) {
		if (_potIsEmpty()) {
			if (_slotHasLoaded(mySlots)) {
				mySlots.forEach((Card card) {
					if (card.contains(touchPoint)) {
						int i = game.rand.nextInt(comSize);
						Card comCard = comSlots.elementAt(i);
						comPot = comCard;
						comCard.sendToPot();
						myPot = card;
						card.sendToPot();
					}
				});
			}
		}
	}
}