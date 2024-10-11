import requests

def send_image_to_server(image_url):
    url = 'http://192.168.4.29:5001/predict'

    data = {
        'url': image_url
    }

    response = requests.post(url, json=data)
    return response.json()

def main():
    # image_path = 'test.jpg'
    image_url = 'https://en.wikipedia.org/wiki/Gun#/media/File:SIG_Pro_by_Augustas_Didzgalvis.jpg'
    result = send_image_to_server(image_url)

    if result['predictions'] is not None:
        for prediction in result['predictions']:
            print(prediction)

if __name__ == '__main__':
    main()